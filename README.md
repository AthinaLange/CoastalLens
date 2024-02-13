# CoastalLens: A MATLAB UAV Video Stabilization & Rectification Framework
Software to stabilize and rectify coastal imagery UAV data. <br />
Developed from the [CIRN Qualitative Coastal Imagining Toolbox](https://github.com/Coastal-Imaging-Research-Network/CIRN-Quantitative-Coastal-Imaging-Toolbox). 

Uncrewed aerial vehicles (UAVs) are an important tool for coastal monitoring with their relatively low-cost and rapid deployment capabilities. To generate scientific-grade image products, the UAV images/videos must be stabilized and rectified into world coordinates. Due to the limited stable region of coastal images suitable for control points, the processing of  UAV-obtained videos can be time-consuming and resource-intensive. The CIRN Qualitative Coastal Imagining Toolbox provided a first-of-its-kind open-sourced code for rectifying these coastal UAV videos. Limitations of the toolbox, however, prompted the development of CoastalLens with an efficient data input procedure, providing capabilities to obtain drone position (extrinsics) from LiDAR surveys, and using a feature detection and matching algorithm to stabilize the video prior to rectification. This framework reduces the amount of human oversight, now only required during the data input processes. Removing the dependency on threshold stability control points can also result in less time in the field. We hope this framework will allow for more efficient processing of the ever-increasing coastal UAV datasets.  

## Installation
Requires MATLAB (min v2022b - for estworldpose function, see [Input Requirements](https://github.com/AthinaLange/UAV_automated_rectification/wiki/Input-Requirements/#GCP) for an alternative if using an older MATLAB version). Ubuntu users: See [Issue 11](https://github.com/AthinaLange/UAV_automated_rectification/issues/11)<br />
Required MATLAB toolboxes:
 - Image Processing Toolbox
 - Computer Vision Toolbox
 - LiDAR Toolbox (to use pointcloud). <br />
 
Requires [exiftool](https://exiftool.org) (or metadata csv file : See [Input Requirements](https://github.com/AthinaLange/UAV_automated_rectification/wiki/Input-Requirements/)) <br/>
Requires [ffmpeg](https://ffmpeg.org/download.html). <br/>
See [Installation Help](https://github.com/AthinaLange/UAV_automated_rectification/wiki/Installation-Help) for installation guides based on your OS. <br />


## Running the Toolbox
Download or clone the repository. 
Run 'UAV_rectification.m' <br />
Will run core scripts in CODES/scripts/ <br />
Requires dependencies in CODES/basicFunctions and CODES/helperFunctions <br />

Running <code>ver</code> in the Command Window will show your MATLAB version and installed toolboxes. <br/>

You can find more details, including the information you need to run this on your own data in our [wiki](https://github.com/AthinaLange/UAV_automated_rectification/wiki/)!

## Demo / Getting Started
'UAV_rectification_DEMO.m' runs a demo version of the code and can also be used to compare the new algorithm versus the CIRN Stability Control Points method. This method requires stability control points to be visible within the field of view. 

Data to test the code is provided in the DATA folder and the video can be downloaded [here](https://drive.google.com/file/d/1Qk1q1i75eXTYNB92fwHlcD6Yg7p0FV_W/view?usp=drive_link) (716MB). Save this video in DATA/20211215_Torrey/Flight_04/.

Here is the input information required for the DEMO version. We recommend making a similar table to keep track of all the necessary information for your own drone flights. <br/>

Flight information: 
![Example_input_file](https://github.com/AthinaLange/UAV_automated_rectification/blob/main/docs/Flight_info_sheet.png)

Origin information:
![Example_origin_file](https://github.com/AthinaLange/CoastalLens/blob/main/docs/Origin_Info_sheet.png)

Products information:
![Example_products_file](https://github.com/AthinaLange/CoastalLens/blob/main/docs/Products_Info_sheet.png)

User prompts/direction is printed in the Command Window. 

## Testing
This toolbox is currently in testing phase on the following systems:
- MacBook Pro M1 2020 (OS 12.6), Matlab 2022b
- MacBook Pro M2 2023 (OS 13.2.1), Matlab 2023a
- Linux (Ubuntu 22.04.3 LTS), Matlab 2022b
- DJI Drones

### Email Updates
The code allows you to recieve email updates as it processes the data. If you do not want to recieve these, please select 'No' to 'Recieve update emails?'. <br/>
If you do, we have set up a Gmail account 'coastallens1903' to use that will be sending the emails, although we recommend you setting up your own account and generating a static App password (16-character) for it moving forward to avoid any security risks. 


## General Folder Structure:
Please set up your CODES and DATA folder in the following structure. The DATA folder may be located in a different folder than your general path, but must be organized as indicated, with all flights in the relevant day/location folder.

```bash
.
├── CODES
│ ├── scripts
│ ├── basicFunctions
│ ├── helperFunctions
├── DATA
│ └── YYYYMMDD_Location1
│     ├── Flight_01
│     ├── Flight_02
│     ├── Flight_03
│ └── YYYYMMDD_Location2
│     ├── Flight_01
│     ├── Flight_02
│     ├── Flight_03
```

## Core Scripts
<table>
<colgroup>
<col width="17%" />
<col width="82%" />
</colgroup>
<thead>
<tr class="header">
<th>Scripts</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td><code> UAV_rectification </code></td>
<td>The main code. Used to rectify and generate data products for user-selected days. </td>
</tr>
<tr class="odd">
<td><code>input_day_flight_data</code></td>
<td> <code>input_day_flight_data</code> returns all user-specified required input data for CoastalLens. </td>
</tr>
<tr class="even">
<td><code>extract_images_from_UAV</code></td>
<td><code>extract_images_from_UAV</code> extracts images from video files at specified frame rates for all flights on specified processing days. Requires ffmpeg.</td>
</tr>
<tr class="odd">
<td><code>stabilize_video</code></td>
<td><code>stabilize_video</code> returns the 2D projective transformation of the image to improve image stabilization through flight. </td>
</tr>
<tr class="even">
<td><code>get_products</code></td>
<td><code>get_products</code> returns extracted image pixel for coordinates of Products and saves Timex, Brightest and Darkest image products. </td>
</tr>
<tr class="odd">
<td><code>save_products</code></td>
<td><code>save_products</code> saves rectified image products from Products in Rectified_images folder. </td>
</tr>
</tbody>
</table>


## Data Output
<table>
<colgroup>
<col width="17%" />
<col width="17%" />
<col width="66%" />
</colgroup>
  
<thead>
<tr class="header">
<th>Variable</th>
<th> Fields </th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td><code>R</code> (structure)</td>
<td> </td>
<td>extrinsics & intrinsics information (stored in *_IOEO_*Hz.mat) </td>
</tr>
<tr class="even"><td> </td>
<td><code>intrinsics</code>(cameraIntrinsics)</td>
<td> camera intrinsic as calibrated in the cameraCalibrator tool</td>
</tr>
<tr class="even"><td> </td>
<td><code>I</code> (uint8 image)</td>
<td> undistorted initial frame </td>
</tr>
<tr class="odd"><td> </td>
<td><code>image_gcp</code> (double)</td>
<td>[n x 2] ground control location in inital frame </td>
</tr>
<tr class="even"><td> </td>
<td><code>world_gcp</code> (double)</td>
<td>[n x 3] ground control location in world coordinate frame (x,y,z) </td>
</tr>
<tr class="even"><td> </td>
<td><code>worldPose</code>(rigidtform3d)</td>
<td>orientation and location of camera in world coordinates, based off ground control location (pose, not extrinsic)</td>
</tr>
<tr class="odd"><td> </td>
<td><code>mask</code>(logical)</td>
<td> mask over ocean region (same dimension as I) - used to speed up computational time (optional) </td>
</tr>
<tr class="odd"><td> </td>
<td><code>feature_method</code>(string)</td>
<td> feature type to use in feature detection algorithm (default: `SIFT`, must be `SIFT`, `SURF`, `BRISK`, `ORB`, `KAZE`)</td>
</tr>
<tr class="odd"><td> </td><td><code>frameRate</code>(double)</td>
<td> frame rate of extrinsics (Hz)</td></tr>
<tr class="odd"><td> </td>
<td><code>extrinsics_2d</code>(projtform2d)</td>
<td> [1 x m] 2d projective transformation of m images. </td>
</tr>

  
<tr class="odd">
<td><code>Products</code>(structure)</td> <td> </td>
<td>Data Products (stored in *_Products.mat)</td>
</tr>
<tr class="even"><td> </td><td><code>productType</code>(string)</td>
<td> 'cBathy' , 'Timestack', 'yTransect'</td></tr>

<tr class="odd"><td> </td><td><code>type</code> (string)</td>
<td> 'Grid', 'xTransect', 'yTransect' </td></tr>

<tr class="even"><td> </td><td><code>frameRate</code> (double) </td>
<td> frame rate of product (Hz) </td></tr>

<tr class="odd"><td> </td><td><code>lat</code> (double)</td>
<td> latitude of origin grid </td></tr>

<tr class="even"><td> </td><td><code>lon</code> (double)</td>
<td> longitude of origin grid </td></tr>

<tr class="odd"><td> </td><td><code>angle</code> (double)</td>
<td> shorenormal angle of origin grid (deg CW from North) </td></tr>

<tr class="odd"><td> </td><td><code>xlim / ylim</code> (double)</td>
<td>cross-/along-shore limits (+ is offshore of origin / right of origin looking offshore) (m)</td></tr>

<tr class="even"><td> </td><td><code>dx/dy</code> (double)</td>
<td> Cross-/along-shore resolution (m) </td></tr>

<tr class="odd"><td> </td><td><code>x / y</code> (double) </td>
<td> Cross-/along-shore distance from origin (m). Used for transects. </td></tr>

<tr class="even"><td> </td><td><code>z</code> (double)</td>
<td> Elevation (m in standard reference frame). Can be NaN (will be projected to 0)or DEM. </td></tr>

<tr class="even"><td> </td><td><code>tide</code> (double)</td>
<td> Tide level (m in standard reference frame). </td></tr>

<tr class="even"><td> </td><td><code>t</code> (datetime array)</td>
<td> [1 x m] datetime of images at given extraction rate in UTC. </td></tr>

<tr class="odd"><td> </td><td><code>localX / localY / localZ</code> (double)</td>
<td> X,Y,Z coordinates of data product in local reference frame (m) </td></tr>

<tr class="odd"><td> </td><td><code>Eastings / Northings </code> (double)</td>
<td> Eastings and Northings coordinates of data product (m) </td></tr>

<tr class="even"><td> </td><td><code>Irgb_2d</code> (uint8 image)</td>
<td> [m x y_length x x_length x 3] timeseries of pixels extracted according to dimensions of xlim and ylim</td></tr>

</tbody>
</table>


## Contributing
Contributions to the toolbox are very welcome! Here are some ways to do that:<br />
- A number of features that we want to include in the future are listed as 'issues'. <br />
- We also want to make sure that we can accommodate other UAV platforms/locations. If you include any changes to be able to process your data in a forked branch, please open a 'pull request' to merge it so other's can also use the addition.  <br />
- One of our goals is to write a Python version of this toolbox, so please let us know if you are interested.  <br />
- Let us know of any other features you would want included.  <br />

If you run into any problems while running the code, or think other things should be included, please let us know by opening an 'issue' or emailing me at alange@ucsd.edu.  


## License

**CoastalLens** is provided under the [MIT license](https://opensource.org/licenses/MIT).


## Cite As
