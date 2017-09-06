function image_splitter(){
	setBatchMode(true);
	main_file = File.openDialog("Select file that needs to be split");
	//open(File.openDialog("Select file that needs to be split"));
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
	List.set(0, "YFP");
	List.set(1, "RFP");
	List.set(2, "CFP");
	List.set(3, "GFP");
	
	getDimensions(width, height, channels, slices, frames);
	work_dir = path + "work_dir";
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
	image_path = path + basename; //werk map voor het plaatje
	File.makeDirectory(image_path);
	run("Close All");
	channels = getFileList(work_dir);
	for(k=0; k < channels.length; k++){
		open(work_dir + File.separator + channels[k]);
		title = getTitle();
		dotIndex = indexOf(title, ".");
		basename = substring(title, 0, dotIndex);
		channel_path = image_path + File.separator + basename;
		File.makeDirectory(channel_path);
		for (z=0; z < List.size; z++){
			image_channel = channel_path + File.separator + List.get(z); //werk map voor het plaatje
			File.makeDirectory(image_channel);
		}
		getLocationAndSize(locX, locY, sizeW, sizeH);
		width = getWidth();
		height = getHeight();
		tileWidth = width / n;
		tileHeight = height / n;
		z = 0;
		for (i=1; i<=nSlices; i++) {  
		 // apply your transformation here,  run("Invert", "slice"); 
		 	z = 0; 
			for (y = 0; y < n; y++) {
		  		offsetY = y * height / n;
		  		for (x = 0; x < n; x++) {
		    		offsetX = x * width / n;
		    		selectWindow(title);
		    		setSlice(i);
		    		call("ij.gui.ImageWindow.setNextLocation", locX + offsetX, locY + offsetY);
		    		tileTitle = basename + i + "[" + x + "," + y + "].tif";
		    		// using the ampersand allows spaces in the tileTitle to be handled correctly 
		    		run("Duplicate...", "title=&tileTitle");
		    		makeRectangle(offsetX, offsetY, tileWidth, tileHeight);
		    		run("Crop");
		    		selectWindow(tileTitle);
		    		saveAs("tiff", channel_path + File.separator + List.get(z) + File.separator +tileTitle);
		    		close();
		    		z++;
		    	}
			}
		}
		run("Close All");
		z = 0;
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

function controles_to_ratio(){
	//pathfile=File.openDialog("Choose the text file for the matrix build to Open:");
	//File.append("test text here \n", pathfile); //add text to file (first variable = text, second = location of file)
	n = getNumber("How many repeats for this FP?", 1);
	fp_name = getString("What is the name of the FP?", "");
	List.set(0, "YFP");
	List.set(1, "RFP");
	List.set(2, "CFP");
	List.set(3, "GFP");
	for(i = 0; i<n; i++){
		channels_nr = image_splitter();
		for(j=0; j<channels_nr; j++){
			controle_dir = getDirectory("Choose a Directory: " + fp_name);
			for (z=0; z < List.size; z++){
				open(controle_dir + File.separator + List.get(z) + ".tif");
			}
			run("ROI Manager...");
			run("Brightness/Contrast...");
			selectWindow(List.get(0)+".tif");
			beep();
			waitForUser("Draw rectangle ");
			roiManager("Add");
			setAutoThreshold("Default dark");
			run("Threshold...");
			beep();
			waitForUser("Select all cells, and add to ROI manager");
			for (z=0; z < List.size; z++){
				selectWindow(List.get(z)+".tif");
				roiManager("Multi Measure");
				saveAs("Results", controle_dir + File.separator + List.get(z)+".csv");
			}
			roiManager("Save", controle_dir + File.separator + "RoiSet.zip");
			list = getList("window.titles");
			run("Close All"); 
			for (k=0; k<list.length; k++){
				winame = list[k]; 
    			selectWindow(winame); 
    			run("Close"); 
			}
		}

	}
}

//print(image_splitter());
controles_to_ratio();


list = getList("window.titles"); 
for (i=0; i<list.length; i++){
	winame = list[i]; 
    selectWindow(winame); 
    run("Close"); 
}