# Coastal UAV rectification software
Software to rectify and create CIRN products for coastal imagery UAV data. <br />
Developed from the [CIRN Qualitative Coastal Imagining Toolbox](https://github.com/Coastal-Imaging-Research-Network/CIRN-Quantitative-Coastal-Imaging-Toolbox). 

## Installation
Requires [exiftool](https://exiftool.org) and [ffmpeg](https://ffmpeg.org/download.html). <br />
Requires XXX MATLAB toolboxes. <br />

## Usage
Run 'UAV_rectification.m' <br />
Will run .m scripts in CODES/scripts/ <br />
Requires dependencies in CODES/basicFunctions and CODES/helperFunctions <br />

## Testing
This toolbox is currently in testing phase on the following systems:
- MacBook Pro M1 2020 (OS 12.6), Matlab 2022b
- MacBook Pro M2 2023 (OS 13.2.1), Matlab 2023a
- DJI Drones
- 
## Recommendations
### Flight:
- take pre- and post-video image for additional metadata, including RTK data
- Toggle distortion correction on

### General Folder Structure:
```bash
.
├── CODES
│ ├── CIRN
│ ├── scripts
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

## Contributing



## License
MIT License
