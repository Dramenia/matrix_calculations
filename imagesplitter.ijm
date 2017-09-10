// functions usable in imagej
// dependencies: StackReg (http://bigwww.epfl.ch/thevenaz/stackreg/) (which requires turboreg (http://bigwww.epfl.ch/thevenaz/turboreg/)

function image_splitter(){
	// splits the images recorded with the quad splitter (2 at question) or other splitters.
	
	// sets the basics that is needed to split the images.
	setBatchMode(true); // increases the run speed. This will not display the images.
	main_file = File.openDialog("Select file that needs to be split");
	open(main_file);
	n = getNumber("How many divisions (e.g., 2 means quarters)?", 2);
	title = getTitle();
	dotIndex = indexOf(title, ".");
	basename = substring(title, 0, dotIndex);
	path = getDirectory("image");
	width = 0;
	height = 0;
	slices = 0;
	channels = 0;
	frames = 0;
	current_channel = 0;
	// changed list of channel names
	List.set(0, "CFP"); // was YFP
	List.set(1, "GFP"); // was RFP
	List.set(2, "YFP"); // was CFP
	List.set(3, "RFP"); // was GFP
	
	// checks if there are multiple channels in the image (for instance, different excitation wavelenghts measured)
	getDimensions(width, height, channels, slices, frames);
	work_dir = path + "work_dir"; // creates a folder that can be removed when script is done. saves each channel here
	File.makeDirectory(work_dir);
	if(channels > 1){
		run("Split Channels");
		for(i=1; i <= channels; i++){
			selectWindow("C" + i + "-" + title);
			saveAs("Tiff", work_dir + File.separator + "C" + i + "-" + title);
		}
	}else{
		saveAs("Tiff", work_dir + File.separator + title);
	}
	image_path = path + basename; // output directory where the split images are saved. basename = title of image
	File.makeDirectory(image_path);
	run("Close All");
	
	// for each file in workdir, opens it, and measures the number of slices (timepoints)
	channels = getFileList(work_dir);
	for(k=0; k < channels.length; k++){
		open(work_dir + File.separator + channels[k]);
		title = getTitle();
		dotIndex = indexOf(title, ".");
		basename = substring(title, 0, dotIndex);
		channel_path = image_path + File.separator + basename;
		File.makeDirectory(channel_path);
		for (z=0; z < List.size; z++){
			image_channel = channel_path + File.separator + List.get(z); // creates a directory per channel (excitation wavelength)
			File.makeDirectory(image_channel);
		}
		getLocationAndSize(locX, locY, sizeW, sizeH); //gets dimensions of main image
		width = getWidth();
		height = getHeight();
		tileWidth = width / n;
		tileHeight = height / n;
		z = 0;
		for (i=1; i<=nSlices; i++) {  // for each slide/timepoint in excitation channel
		 	z = 0; 
			for (y = 0; y < n; y++) {
		  		offsetY = y * height / n;
		  		for (x = 0; x < n; x++) {
		    		offsetX = x * width / n;
		    		selectWindow(title);
		    		setSlice(i);
		    		call("ij.gui.ImageWindow.setNextLocation", locX + offsetX, locY + offsetY); // selects one of the N channels (sections) of the image
		    		tileTitle = basename + i + "[" + x + "," + y + "].tif";
		    		// using the ampersand allows spaces in the tileTitle to be handled correctly 
		    		run("Duplicate...", "title=&tileTitle");
		    		makeRectangle(offsetX, offsetY, tileWidth, tileHeight);
		    		run("Crop"); // removes all channels (sections) that do not belong to the selected channel
		    		selectWindow(tileTitle);
		    		saveAs("tiff", channel_path + File.separator + List.get(z) + File.separator +tileTitle);
		    		close();
		    		z++;
		    	}
			}
		}
		run("Close All");
		z = 0;
		// aligns first slide from each channel (section) 
		for (y = 0; y < n; y++) {
			for (x = 0; x < n; x++){
				tileTitle = basename + "1[" + x + "," + y + "].tif";
				open(channel_path + File.separator + List.get(z) + File.separator +tileTitle);//open alle eerste frames, en dan in stack, en dan stackreg
				z ++;
			}
		}
		run("Images to Stack", "name=firstSlide use");
		run("StackReg ", "transformation=[Rigid Body]");
		z = 0;
		for (y = 0; y < n; y++) {
			for (x = 0; x < n; x++){
				selectWindow("firstSlide");
				setSlice(z+1);
				tileTitle = basename + "1[" + x + "," + y + "].tif";
				run("Duplicate...", "title=&tileTitle");
				saveAs("tiff",channel_path + File.separator + List.get(z) + File.separator +tileTitle);
				z ++;
			}
		}
		
		// aligns remaining slides of channel (section) with first aligned slide from channel (section)
		for (z=0; z < List.size; z++){
			run("Close All");
			images = getFileList(channel_path + File.separator + List.get(z) + File.separator );
			for (f=0; f < images.length; f++){
				open(channel_path + File.separator + List.get(z) + File.separator  + images[f]);
			} 
			// make stack from open images, and close all
			if(images.length > 1){
				run("Images to Stack", "name=" + List.get(z) + " use");
				run("StackReg ", "transformation=[Rigid Body]");
				saveAs("Tiff", channel_path + File.separator + List.get(z));
			}else{
				saveAs("Tiff", channel_path + File.separator + List.get(z));
			}
		}
		run("Close All");
	}
	setBatchMode(false);
	return channels.length;
}

function intensity_measurement_controls(){
	// exports the control images to csv values. before use, make sure the multimeasure is set to mean grey value!
	n = getNumber("How many repeats for this FP?", 1);
	fp_name = getString("What is the name of the FP?", "");
	List.set(0, "CFP");
	List.set(1, "GFP");
	List.set(2, "YFP");
	List.set(3, "RFP");
	// for each repeat of the fluor, do the splitting
	for(i = 0; i<n; i++){
		channels_nr = image_splitter(); // channel number is number of split excitation channels. This number is returned by image_splitter
		for(j=0; j<channels_nr; j++){
			controle_dir = getDirectory("Choose a Directory: " + fp_name);
			for (z=0; z < List.size; z++){
				open(controle_dir + File.separator + List.get(z) + ".tif");
			}
			run("ROI Manager...");
			run("Brightness/Contrast...");
			selectWindow(List.get(0)+".tif");
			beep();
			waitForUser("Draw rectangle of background");
			roiManager("Add");
			setAutoThreshold("Default dark");
			run("Threshold...");
			beep();
			waitForUser("Select all cells, and add to ROI manager");
			for (z=0; z < List.size; z++){
				selectWindow(List.get(z)+".tif");
				roiManager("Multi Measure");
				saveAs("Results", controle_dir + File.separator + List.get(z)+".csv");
			} //saves mean grey value of all the ROIs (incl background)
			roiManager("Save", controle_dir + File.separator + "RoiSet.zip");
			list = getList("window.titles");
			run("Close All"); 
			for (k=0; k<list.length; k++){
				winame = list[k]; // door alle channels (for example multiple excitation settings)
    			selectWindow(winame); 
    			run("Close"); 
			}
		}

	}
}

//print(image_splitter());
intensity_measurement_controls();


list = getList("window.titles"); 
for (i=0; i<list.length; i++){
	winame = list[i]; 
    selectWindow(winame); 
    run("Close"); 
}
