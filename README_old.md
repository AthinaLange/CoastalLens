# UAV_automated_rectification
Toolbox to rectify UAV video in coastal oceanography

# STILL IN PROGRESS -- NOT TO BE USED YET

## Still TODO
 - SMTP Server stuff
 - DEM option
 - write get_noaa_lidar
 - improve get_pointcloud_gcp
 - write google earth method
 - write automated lidar method
 - include gcp reprojection error
 - include grid dimensions check
 - add documentation for gcp methods

## Additional comments
- if same day/location, but using different cameras/drone, please name folders differently
- only have relevant videos to be processed in the folder

#### Testing:
This toolbox is currently in testing phase on the following systems:
- MacBook Pro M1 2020 (OS 12.6), Matlab 2022b
- MacBook Pro M2 2023 (OS 13.2.1) Matlab 2023a
- DJI Drones

#### Flight recommendations:
- take pre- and post-video image for additional metadata, including RTK data
- Toggle distortion correction on

## To get started:
 - Download the movie at drone/data/cbathy/20211026_Torrey/1/DJI_0003.MOV to get and put it in folder DATA/20211026_Torrey/01 (see folder structure below) as sample data.
 - Install exiftool (details on how to install here: https://exiftool.org/). This will be used to extract the metadata from the images.
 - Install ffmpeg (details here: https://ffmpeg.org/download.html). Note to ARM mac users (M1, M2 silicon): ffmpeg is not built for ARM macs, but the intel install should work fine. You will need to allow ffmpeg to run on your computer by explicity allowing the application in the security & privacy tab of system preferences.
 - _TODO_ What should be in the cBathy2.0 folder?? Should it be the full cBathy-Toolbox repo? (details here: https://github.com/Coastal-Imaging-Research-Network/cBathy-Toolbox)

### General Folder Structure:
```bash
.
├── CODES
│ ├── CIRN
│ ├── basicFunctions
│ ├── helperFunctions
│ ├── cBathy_2.0
├── DATA
│ └── YYYYMMDD_Location1
│     ├── 01
│     ├── 02
│     ├── 03
│ └── YYYYMMDD_Location2
│     ├── 01
│     ├── 02
│     ├── 03
```


## To Run:
UAV_rectification_v09_2023_function_based.m (will then run user_input_data.m and extract_images.m)

### Housekeeping:
- find global directory where CODES and DATA folder are stored.
- add CODES file to path and confirm the CIRN, cBathy 2.0, and basic/helperFunctions folders are loaded
- specify which UAV hovers you want to process (have to do all of a given day at once)
- Input name and email where test emails will go to
    - The SMTP server might need to be fixed. 
- Save: directory paths, data_folders to process and user email

### User Input:
requires [ffmpeg](https://ffmpeg.org/) install
requires [exiftool](https://exiftool.org/) install
requires: data_files, global_dir (and user_email)
- confirm that you get test email - if email SMTP server not correctly configured, can make changes in code here. 
- for every hover day folder repeat process:
    - check with user if they have already saved an input_data.mat file with the general drone / products information
    - specify drone system, e.g. DJI or other. Will help define the video naming convention to be used.
    - specify video timezone - assuming video metadata in local timezone, otherwise pick UTM
    - find MATLAB camera calibration file for UAV (cameraParameters) - otherwise go do that and come back - should have a distortion and undistorted version of camera calibration (cameraParams_distorted and cameraParams_undistorted) - if only a single calibration (cameraParams)
        - if none exists, will prompt the MATLAB cameraCalibrator app
    - define your data products to be created (do you want to load in a Products .mat file or define them here?)
        - load in .mat file of origin data grid = (Lat, Lon, shorenormal angle) OR define in pop-up window - lat has to be +-90deg, lon +-180 and shorenormal angle within 360deg defined CC from North (see CDIP MOP angle definitions for examples)
        - for every data product that you want to define - select from Grid (cBathy), xTransect (Timestack) or yTransect (there is the option to self define but that still needs to be expanded on)
        - Input for every data type:
            - for Grid:
               - frame rate (assuming max frame rate of the camera is 30Hz) 
               - Offshore cross-shore extent in meters from Origin - grid extended to 700m offshore? -> 700
               - Onshore cross-shore extent in meters from Origin - grid starts at 100m back/onshore from origin -> 100
               - southern alongshore extent in meters from Origin - grid extends 300m south of origin -> 300 (if shorenormal angle < 180deg, assuming East Coast and southern limit is to the right of origin when looking offshore, if shorenormal angle > 180deg, assuming West Coast and southern limit is to the left of origin, looking offshore)
               - northern alongshore extent in meters from Origin - grid extends 300m north of origin -> 300 (if shorenormal angle < 180deg, assuming East Coast and northern limit is to the left of origin when looking offshore, if shorenormal angle > 180deg, assuming West Coast and northern limit is to the right of origin, looking offshore)
               - dx and dy in meters - cross-shore and alongshore grid spacing
               - z in appropriate datum - STILL NEED TO ADD IN DEM OPTION
              
            - for xTransect:
               - frame rate (assuming max frame rate of the camera is 30Hz)
               - Offshore cross-shore extent in meters from Origin - timestack extended to 700m offshore? -> 700
               - Onshore cross-shore extent in meters from Origin - timestack starts at 100m back/onshore from origin -> 100
               - alongshore locations of transects in meters from Origin - can be either comma-separated list (-100, 0, 100) or array ([-100: 100:100])
               - dx in meters - cross-shore spacing
               - z in appropriate datum - STILL NEED TO ADD IN DEM OPTION
            - for yTransect:
               - frame rate (assuming max frame rate of the camera is 30Hz)
               - southern alongshore extent in meters from Origin - transect extends 300m south of origin -> 300 (if shorenormal angle < 180deg, assuming East Coast and southern limit is to the right of origin when looking offshore, if shorenormal angle > 180deg, assuming West Coast and southern limit is to the left of origin, looking offshore)
               - northern alongshore extent in meters from Origin - transect extends 300m north of origin -> 300 (if shorenormal angle < 180deg, assuming East Coast and northern limit is to the left of origin when looking offshore, if shorenormal angle > 180deg, assuming West Coast and northern limit is to the right of origin, looking offshore)
               - cross-shore locations of transects in meters from Origin - can be either comma-separated list (100, 200, 300) or array ([100: 100:300]) - assuming only looking offshore of origin
               - dy in meters - alongshore spacing
               - z in appropriate datum - STILL NEED TO ADD IN DEM OPTION
          
    - find the minimum number of frames needed to be extracted (2Hz data can be pulled from 10Hz images, but 3Hz cannot. Code will then extract frames at 3Hz and 10Hz)
    
    - Save cameraParameters, extraction frame rate (extract_Hz), Products, number of flights on given day (flights), timezone (tz) and drone type (drone_type) as input_data.mat
 
    - for every flight repeat process:
        - extract meta data from images and videos (REQUIRES EXIFTOOL) - Assuming that all videos in the folder need to be processed - INPUT FOR OTHER SYSTEMS/USES REQUIRED
        - making initial extrinsics guess based on meta data (converted to UTM Coodinates [GPSEasting, GPSNorthing, AbsoluteAltitude - zgeoid_offset, CameraYaw + 360, CameraPitch+90, CameraRoll]
        - Extract 1st frame of video to do initial extrinsics calibration on
        - Confirm whether correct cameraParameters are used - assuming a distorted and undistorted camera calibration has been done, confirm which distortion model to use - Default for our flights is distortion correction ON, so cameraParams_undistorted would be used. 
        - use ground control points to obtain initial camera position and pose (extrinsics) - select method to use
          (see Wiki for more info on various options).
            - Option 1: Automated with LiDAR survey
            - Option 2: Manual gcp selection from LiDAR or SfM survey (DONE)
            - Option 3: Manual gcp selection from GoogleEarth
            - Option 4: Manual gcp selection from targets (QCIT Toolbox) (DONE)
            - Option 5: No gcp - use camera metadata
          get CIRN extrinsics and MATLAB worldPose - if more points are needed, user prompted to select more from Options 2-4
        - specify if you want to use SCPs or Feature Matching for image stabilization
        - if image stabilization via Feature Matching
            - Extract images every 30sec from all videos (using VideoReader)
            - Determine how much of image area should be useable for feature matching (how much beach) - improves code speed
            - Does 2D warping for relative movement between frames (depending on how much rotation is needed, decide between 2D or 3D)
        - if image stabilization via SCPs (QCIT)
            - Define SCPs (using same points as GCP targets)
              define radius, bright/dark, and threshold - specify elevation
        - check that grid dimensions for cBathy data and timestacks is appropriate. If not, follow prompt until you are happy (currently requires input, changed grid cannot be a file).
        - send email with provided information:
            - Origin coordinates
            - initial extrinsics guess
            - gcp-corrected extrinsics with method note
            - MATLAB worldPose and image stabilization method (2D, 3D, SCP)
            - frame rate of data to be extracted
            - Products to produce with type, frame rate and dimensions
            - Distortion-corrected image, GCP image,  Rectified grid, and timestacks on oblique image


### Extract Images
requires [ffmpeg](https://ffmpeg.org/) install
requires data_files (and user_email)

- for each day and flight:
    - for each extraction frame rate:
        - make directory for given extraction frame rate (e.g. images_10Hz/)
        - for each movie in directory: extract images from video at extraction frame rate using ffmpeg (images placed in new subfolder)
        - move images from movie subfolders into extraction rate directory (e.g. images_10Hz/) and name images sequentially. delete movie subfolders.
    - send email that image extraction complete


### Image Stabilization
Tracks image stabilization through UAV flight
requires data_files (and user_email)

- for each day and flight:
    - for each extraction frame rate:
        - if using feature matching (monocular visual odometry)
            - within user-specified region of interest (bottom % of image) detect SURF feature and extract features in first frame
            - for all subsequent frames:
               - detect SURF features in current frame
               - find matching features between current and first frame (to avoid camera drift)
               - if using 2D rotation
                  - estimate 2D image transformation - (x,y) shift and rotation angle
               - if using 3D transformation
                  - estimate essential matrix
                  - estimate relative pose
                    if multiple relative poses found:
                     - get coordinates of origin (or any known point within the field of view)
                     - project coordinates into image according to 3D transformations
                     - if projected point is outside image dimensions - pose is incorrect
                     - if multiple poses satisfy this - take smallest Euclidian distance between projected points in current frame and projected origin in previous frame
                  - get worldPose for each frame from worldPose.A * relPose.A
        - if using SCP (based on QCIT [F_variableExtrinsicsSolution](https://github.com/Coastal-Imaging-Research-Network/CIRN-Quantitative-Coastal-Imaging-Toolbox/wiki/3.-Script-Descriptions:-F_variableExtrinsicSolution))
            - within radius of previous location of SCPs, find mean location of pixels above/below specified threshold. This becomes the new location of the SCP.
            - Find the new extrinsics based on new SCP locations.
           if no points above/below threshold, then user prompt to click the location of the point
          if same point is clicked 5 times in the last 10 frames, then redo radius and threshold
          if person/thing walks across point, user can pause code and click on points until object is gone (still TBD).

  
### Create Products
Generate rectified grids and transects based on image stabilization
