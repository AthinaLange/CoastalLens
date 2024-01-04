# Coastal UAV rectification software
Software to rectify and create CIRN products for coastal imagery UAV data.

## Installation
Requires exiftool and ffmpeg.
Requires XXX MATLAB toolboxes.

## Recommendations
### Flight:
- take pre- and post-video image for additional metadata, including RTK data
- Toggle distortion correction on

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

### Testing
This toolbox is currently in testing phase on the following systems:
- MacBook Pro M1 2020 (OS 12.6), Matlab 2022b
- MacBook Pro M2 2023 (OS 13.2.1), Matlab 2023a
- DJI Drones

## Usage
UAV_rectification.m

## Contributing



## License
MIT License
