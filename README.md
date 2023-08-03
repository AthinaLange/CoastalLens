# UAV_automated_rectification
Toolbox to rectify UAV video in coastal oceanography

Flight recommendations: 
- take pre- and post-video image for additional metadata, including RTK data
- Toggle distortion correction on

Requirements:
- CODES folder
    - CIRN
    - cBathy_2.0
    - basicFunctions
- DATA folder
    - YYYYMMDD_Location1
        - 01
        - 02
        - 03
    - YYYYMMDD_Location2
        - 01
        - 02
        - 03


Housekeeping:
- find global directory where CODES and DATA folder are stored.
- specify which UAV hovers you want to process (have to do all of a given day at once)
- Input name and email where test emails will go to
- Save: directory paths, data_folders to process and user email

User Input:
- confirm that you get test email
- for every hover day folder repeat process:
    - find MATLAB camera calibration file for UAV (cameraParameters) - otherwise go do that and come back - should have a distortion and undistorted version of camera calibration
    - at what frequency do you want the images to be extracted at? (e.g. 2, 10 Hz)
        - assuming max frame rate of the camera is 30Hz - but can be changed (L70)
    - find the minimum number of frames needed to be extracted (2Hz data can be pulled from 10Hz images, but 3Hz cannot. Code will then extract frames at 3Hz and 10Hz)
    - create grid file:
        - Local coordinate system (NOT RECOMMENDED): only needs cross-shore and alongshore distance and dxdy - assumes that camera extrinsics given relative to this.
        - World coordinate system (RECOMMENDED): requires latitude and longitude of origin, cross-shore and alongshore distance, rotation angle of grid and dxdy - extrinsics given in lat/long values. Allows for shorenormal grid to be constructed. Grid can then be adjusted to a local coordinate system.
            - grid can either be data input of as a .mat file: grid = [latitude of origin, longitude of origin, cross-shore distance, alongshore distance, rotation angle from N in degrees]
    - Save cameraParameters, frame rate, grid data and number of flights on given day
 
    - for every flight repeat process:
        - extract meta data from images and videos (REQUIRES EXIFTOOL) - to account for false-start videos, only starting at first full length video (DJI: 5:28min) and going to end - MORE INPUT FROM OTHER SYSTEMS/USES REQUIRED
        - making initial extrinsics guess based on meta data [GPSLatitude, GPSLongitude, RelativeAltitude - zgeoid_offset, CameraYaw + 360, CameraPitch+90, CameraRoll]
        - Extract 1st frame of video to do initial extrinsics calibration on
        - Confirm wether correct cameraParameters are used - assuming a distorted and undistorted camera calibration has been done, confirm which distortion model to use - Default for our flights is distortion correction ON, so cameraParams_undistorted would be used. 
    -   check that grid dimensions for cBathy data and timestacks is appropriate. If not, follow prompt until you are happy (currently requires input, changed grid cannot be a file).
    -   send email with provided information:
        - frame rate of data to be used
        - frame rate of data to be extracted
        - grid dimensions
        - initial extrinsics guess (and TBD LiDAR-based correction)
        - Grid overlayed on image and intrinsics corrected image




