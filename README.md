# Coastal UAV rectification software
Software to rectify and create CIRN products for coastal imagery UAV data. <br />
Developed from the [CIRN Qualitative Coastal Imagining Toolbox](https://github.com/Coastal-Imaging-Research-Network/CIRN-Quantitative-Coastal-Imaging-Toolbox). 

## Installation
Requires [exiftool](https://exiftool.org) and [ffmpeg](https://ffmpeg.org/download.html). <br />
Requires XXX MATLAB toolboxes. <br />

## Getting Started
Run 'UAV_rectification_v01_2024.m' <br />
Will run .m scripts in CODES/scripts/ <br />
Requires dependencies in CODES/basicFunctions and CODES/helperFunctions <br />

## Demo (TBD)
'UAV_rectification_DEMO.m' runs a demo version of the code. This will run the feature detection method and using Stability Control Points (based on CIRN QCIT code) and let you compare results.  

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

## Contributing



## License
MIT License

