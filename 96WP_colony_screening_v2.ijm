//Initial setup
run("Roi Defaults...", "color=cyan stroke=5 group=0");
run("Set Measurements...", "area redirect=None decimal=3");
roiManager("Reset");

//Set input and output folders from user input
//Input folder should only contain images
//Images should be named using numbers and well IDs in the format "00001 A1"
//Output folder should be empty
#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix
list = getFileList(input);

//Create results table with well IDs
Table.create("Results summary");
list2 = newArray(list.length);
for (i=0; i<list.length; i++) {
	list2[i] = substring(list[i],6,lengthOf(list[i])-4);
}
Table.setColumn("Well ID", list2);
Table.setColumn("Call")

//Create an image to save segmented colony images 
newImage("ColonyOutlines", "RGB black", 1800, 1800, list.length);

//Colony segmentation
for (i=0; i<list.length; i++) {
	//Open images
	open(input+"/"+list[i]);
	//Remove the well edge
	//Image size and mask sizes can be adjusted for your images
	makeOval(14, -77, 1712, 1718);
	run("Copy");
	run("Close");
	newImage("Crop", "8-bit black", 1800, 1800, 1);
	run("Paste");
	run("Select All");
	run("Duplicate...", "title=Untitled");
	//Remove the dark background
	//Background subtraction parameters can be adjusted for your images
	run("RGB Color");
	run("Colour Deconvolution", "vectors=H&E");
	close("Untitled-(Colour_3)");
	close("Untitled-(Colour_1)");
	close("Colour Deconvolution");
	close("Untitled");
	selectWindow("Untitled-(Colour_2)");
	run("Grays");
	run("Subtract Background...", "rolling=1 dark disable");
	setMinAndMax(1, 20);
	run("Apply LUT");
	//Enhance the colony area
	//Convolution and gaussian blur parameters can be adjusted for your images
	run("Convolve...", "text1=[-1 -1 -1 -1 -1\n-1 -1 -1 -1 -1\n-1 -1 12 -1 -1\n-1 -1 -1 -1 -1\n-1 -1 -1 -1 -1\n] normalize");
	run("Gaussian Blur...", "sigma=50");
	//Threshold the colony area
	//The threshold value can be ajusted for your images to detect colonies and exclude background
	setAutoThreshold("Default");
	run("Threshold...");
	setThreshold(22, 255);
	setOption("BlackBackground", false);
	//Convert to objects
	run("Convert to Mask");
	run("Watershed");
	run("Analyze Particles...", "add");
	//If no objects, create a 1x1 rectangle 
	n=roiManager("count");
	if (n<1) {
		makeRectangle(0, 0, 1, 1);
		setBackgroundColor(0, 0, 0);
		run("Clear", "slice");
		run("Convert to Mask");
		run("Watershed");
		run("Analyze Particles...", "add");
		n=roiManager("count");
	}
	//Measure object area
	for (f = 0; f < n; f++) {
		roiManager("Select", f);
		run("Measure");
	}
	//If >1 object, sort by decreasing area
	if (n>1) {
		selectWindow("Results");
		Table.sort("Area");
		p = Table.size;
		Table.setColumn("idx", Array.reverse(Array.getSequence(p)));
		Table.sort("idx");
		Table.deleteColumn("idx");
	}
	//Index object area into Results summary table
	for (t = 0; t < n; t++) {
		list3 = getResult("Area", t);
		//For 1x1 rectabgles, set area to 0
		if (list3 == 1) {
			list3 = 0;
		}
		//Input values into the results table
		selectWindow("Results summary");
		a = t+1;
		Table.set("Area"+a, i, list3);
		Table.update();
	//Limit results to the largest 3 objects for each image
		if (t == 2) {
			t = p;
		}	
	}
	//Create an overlay of the segmented objects with the original image
	selectWindow("Crop");
	n=roiManager("count");
	for (f = 0; f < n; f++) {
		roiManager("Select", f);
		Overlay.addSelection;
	}
	run("Flatten", "slice");
	run("Select All");
	run("Copy");
	run("Close");
	selectWindow("ColonyOutlines");
	setSlice(i+1);
	run("Paste");
	//Reset for next round
	close("Untitled-(Colour_2)");
	close("Threshold");
	close("Crop");
	close("Results");
	roiManager("Reset");
}

//Make positive/negative calls for each image
//The size threshold for positive calls can be modified to be more or less stringent
selectWindow("Results summary");
Result_length = Table.size("Results summary");
for (i=0; i<Result_length; i++) {
	area_1 = Table.get("Area1", i);
	//Identify wells with objects
	if (area_1 > 1) {
		area_2 = Table.get("Area2", i);
		//Exclude wells with secondary objects larger than 30000
		if (area_2 > 30000) {
			Table.set("Call", i, "Negative");
		}else {
			Table.set("Call", i, "Positive");
		}
	} else {
		Table.set("Call", i, "Negative");
	}
}

//Save result images
selectWindow("ColonyOutlines");
setSlice(1);
saveAs("tiff", output+"/ColonyOutlines");

//Save result table
selectWindow("Results summary");
saveAs("Results", output+"/ColonyResults.csv");
