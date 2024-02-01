# Coastal UAV rectification software
Software to rectify and create data products for coastal imagery UAV data. <br />
Developed from the [CIRN Qualitative Coastal Imagining Toolbox](https://github.com/Coastal-Imaging-Research-Network/CIRN-Quantitative-Coastal-Imaging-Toolbox). 

Uncrewed aerial vehicles (UAVs) are an important tool for coastal monitoring with their relatively low-cost and rapid deployment capabilities. To generate scientific-grade image products, the UAV images/videos must be rectified into world coordinates, requiring GPS-surveyed ground and stability control points throughout the image to obtain the variable UAV extrinsics. Due to the limited stable region of coastal images suitable for control points,  the processing of  UAV-obtained videos can be time-consuming and resource-intensive. The necessity of stability control points increases the time in the field. We develop a new automated UAV rectification tool which utilizes widely available resources, such as airborne-LiDAR surveys and feature-detection algorithms, to reduce the amount of human oversight often required in these rectifications.  An automated rectification tool will allow more efficient processing of the ever-increasing coastal UAV datasets. 

## Installation
Requires MATLAB (developed on v2022b and has not been tested on prior versions) <be />
Requires [exiftool](https://exiftool.org) and [ffmpeg](https://ffmpeg.org/download.html). <br />
Requires XXX MATLAB toolboxes. <br />

## Getting Started
Run 'UAV_rectification_v01_2024.m' <br />
Will run .m scripts in CODES/scripts/ <br />
Requires dependencies in CODES/basicFunctions and CODES/helperFunctions <br />

## Demo (TBD)
'UAV_rectification_DEMO.m' runs a demo version of the code to compare the new algorithm versus the CIRN Stability Control Points method. This method requires stability control points to be visible within the field of view. 

Data to test the code is provided in the DATA folder.

## Testing
This toolbox is currently in testing phase on the following systems:
- MacBook Pro M1 2020 (OS 12.6), Matlab 2022b
- MacBook Pro M2 2023 (OS 13.2.1), Matlab 2023a
- DJI Drones

## Recommendations
### Flight:
- take pre- and post-video image for additional metadata, including RTK data
- Toggle distortion correction on
- Video formats 'MOV', 'MP4', 'TS' (add to metadata section in input_day_flight_data.m)

### General Folder Structure:
```bash
.
├── CODES
│ ├── scripts
│ ├── basicFunctions
│ ├── helperFunctions
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
<td><code>UAV_rectification</code></td>
<td>The main code. Used to rectify and generate data products for user-selected days. </td>
</tr>
<tr class="odd">
<td><code>input_day_flight_data</code></td>
<td>Requires user input. Obtains camera intrinsics and initial extrinsics and grid locations to extract products. Requires exiftool. </td>
</tr>
<tr class="even">
<td><code>extract_images_from_UAV</code></td>
<td>Extracts images from videos. Requires ffmpeg.</td>
</tr>
<tr class="odd">
<td><code>run_extrinsics</code></td>
<td>Determines changing camera projection using feature detection algorithms (default: SIFT Features). </td>
</tr>
<tr class="even">
<td><code>get_products</code></td>
<td>Extracts pixels at grid locations from camera projection to generate data products. </td>
</tr>
</tbody>
</table>

### Data Output
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
<td><code>R</code></td>
<td> </td>
<td>Structure: extrinsics information (stored in *_IOEO_*Hz.mat) </td>
</tr>
<tr class="even"><td> </td>
<td><code>intrinsics</code></td>
<td> cameraIntrinsics - from cameraCalibrator </td>
</tr>
<tr class="odd"><td> </td>
<td><code>image_gcp</code></td>
<td>[n x 2] ground control location in inital frame </td>
</tr>
<tr class="even"><td> </td>
<td><code>world_gcp</code></td>
<td>[n x 3] ground control location in world coordinate frame (x,y,z) </td>
</tr>
<tr class="even"><td> </td>
<td><code>worldPose</code></td>
<td>rigidtform3d object - world Pose of camera, based off ground control location</td>
</tr>
<tr class="odd"><td> </td>
<td><code>mask</code></td>
<td> mask over ocean region - used to speed up computational time </td>
</tr>
<tr class="odd"><td> </td>
<td><code>extrinsics_2d</code></td>
<td> projtform2d - 2d projective transformation of image. </td>
</tr>

  
<tr class="odd">
<td><code>Products</code></td><td> </td>
<td>Structure: Data Products (stored in *_Products_*Hz.mat)</td>
</tr>

<tr class="even"><td> </td>
<td><code>productType</code></td>
<td> string: 'cBathy', 'Timestack', 'yTransect' </td>
</tr>
<tr class="odd"><td> </td>
<td><code>type</code></td>
<td> string: 'Grid', 'xTransect', 'yTransect' </td>
</tr>
<tr class="even"><td> </td>
<td><code>frameRate</code></td>
<td> frame rate of product (Hz) </td>
</tr>
<tr class="odd"><td> </td>
<td><code>lat</code></td>
<td> latitude of origin grid </td>
</tr>
<tr class="even"><td> </td>
<td><code>lon</code></td>
<td> longitude of origin grid </td>
</tr>
<tr class="odd"><td> </td>
<td><code>angle</code></td>
<td> shorenormal angle of origin grid (deg CW from North) </td>
</tr>
<tr class="even"><td> </td>
<td><code>t</code></td>
<td> datetime of images at given extraction rate in UTC. </td>
</tr>
<tr class="odd"><td> </td>
<td><code>xlim / ylim</code></td>
<td>cross-/along-shore limits (+ is offshore of origin / right of origin looking offshore) (m) </td>
</tr>
<tr class="even"><td> </td>
<td><code>dx/dy</code></td>
<td> Cross-/along-shore resolution (m) </td>
</tr>
<tr class="odd"><td> </td>
<td><code>x / y</code></td>
<td> Cross-/along-shore distance from origin (m). Used for transects. </td>
</tr>
<tr class="even"><td> </td>
<td><code>z</code></td>
<td> Elevation (m in standard reference frame). Can be NaN (will be projected to 0), tide level or DEM. </td>
</tr>
<tr class="odd"><td> </td>
<td><code>localX / localY / localZ</code></td>
<td> X,Y,Z coordinates of data product in local reference frame (m) </td>
</tr>
<tr class="even"><td> </td>
<td><code>Irgb_2d</code></td>
<td> Data product</td>
</tr>

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
MIT License

