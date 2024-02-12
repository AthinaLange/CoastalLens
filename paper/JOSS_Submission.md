---
title: 'CoastalLens: A MATLAB UAV Video Stabilization & Rectification Framework'
tags:
  - MATLAB
  - Coastal Oceanography
  - UAV
  - Video stabilization
  - Image Rectification
authors: 
  - name: Athina M.Z. Lange
    orcid: 
    equal-contrib: true
    affiliation: 1
  - name: Holger Lange
    orcid: 
    equal-contrib: true
    affiliation: 2
  - name: Brittany L. Bruder
    orcid: 
    equal-contrib: true
    affiliation: 3
  - name: J.W. Fiedler
    orcid: 
    equal-contrib: true
    affiliation: 4
affiliations:
  - name: Scripps Institution of Oceanography, University of California, San Diego, USA
    index: 1
  - name: AI Werkstatt, Ft. Lauderdale, USA
    index: 2
  - name: Coastal and Hydraulics Laboratory, US Army Engineer Research and Development Center, USA
    index: 3
  - name: Sea Level Rise Center, University of Hawai’i Manoa, USA
    index: 4
date: 29 Feburary 2024
bibliography: paper.bib
---

# Statement of need
Uncrewed aerial vehicles (UAVs) are an important tool for coastal monitoring with their relatively low-cost and rapid deployment capabilities. To generate scientific-grade image products, the UAV images/videos must be stabilized and rectified into world coordinates. Due to the limited stable region of coastal images suitable for control points, the processing of  UAV-obtained videos can be time-consuming and resource-intensive. The [CIRN Qualitative Coastal Imagining Toolbox](https://github.com/Coastal-Imaging-Research-Network/CIRN-Quantitative-Coastal-Imaging-Toolbox) provided a first-of-its-kind open-sourced code for rectifying these coastal UAV videos. Limitations of the toolbox, however, prompted the development of CoastalLens with an efficient data input procedure, providing capabilities to obtain drone position (extrinsics) from LiDAR surveys, and using a feature detection and matching algorithm to stabilize the video prior to rectification. This framework reduces the amount of human oversight, now only required during the data input processes. Removing the dependency on threshold stability control points can also result in less time in the field. We hope this framework will allow for more efficient processing of the ever-increasing coastal UAV datasets. 

# Summary
CoastalLens is set up as 4 scripts (with an optional 5th script) run sequentially from a main code (``UAV_rectification``). This allows users to execute parts or all of the full framework as is useful in their workflow. ``input_day_flight_data`` returns all the user-specified required input data. The user is required to input data for each day and flight to process. This code requires user input about the video timezone, camera intrinsics, the Products to be generated (e.g. Grid/Rectified Image, xTransect or yTransect), and the ground control points to determine the camera world position (via GPS points or pointcloud). Users can load in pre-set values for the relevant day-specific information from a configuration file. This is useful if similar UAV missions are flown repeatedly at the same location. ``extract_images_from_UAV`` extracts images from the video files at the specified frame rates. This is done via a system command to the ffmpeg command line tool. 
``run_extrinsics`` returns the 2D projective transformation of the image to improve image stabilization through flight. We take an approach similar to constructing a panorama image. Features (e.g. corners, windows, lines on the ground) are found in every frame. In subsequent frames, these features are matched and the movement/change in location of these features between the frames is used to estimate the change in position of frame 2 versus frame 1. This is used to warp the image into fitting into the full ‘panorama’ image. This approach allows for good estimates to be obtained even in cases where the UAV drift substantially. In ``get_products`` the world coordinates of the previously defined products have corresponding image coordinates. These image coordinates are used to extract the pixels from each frame. ``save_products`` is an optional code to save the resulting rectified images as png’s.

![Figure 1: Example of matched features and the 2D projective transformation of the image. (left) Image 1 (red) and Image 2 (blue) are taken 1 minute apart (extreme case) and features have been detected and matched between the two frames. Note the shift in the lifeguard tower on the right, or the pedestrian crosswalk in the middle of the image. (right) Image 1 (green) and Image 2 (purple) shown after they have been warped into the ‘panorama’ image. Note large grey region at the bottom and the horizon at the top of the image where the two frames match and the stabilization has succeeded.\label{fig:1}](https://github.com/AthinaLange/CoastalLens/blob/main/docs/get_extrinsics_fd_example.png)


![Figure 2: Example of 17 minutes of video stitched together. Extreme drift in the UAV can be seen, but horizon at the top and road at the bottom of the image remain stable.\label{fig:2}](https://github.com/AthinaLange/CoastalLens/blob/main/docs/20211026_Torrey_01_Panorama.png)


# References
