## Just a Python and Cloudformation repository

This repository contains two directories:
- The directory *dir1* contains a sample python3 script that would download a bunch of files in parallel. Right now it supports http, https and S3.

### Python script

The python script can receive two different flags:
- The *-h* shows the help
- The *-u|--url* can receive one or remote url (http, https and s3 urls).

The script will download the requested files in the current directory. If one file appears more than once, only the last one will be downloaded (to avoid downloading the same file more than once).

When the script finishes it will report the status of the downloads.

If one file does uses an unsupported url scheme, the script will report that and exit with error code *1*

Upon exiting, if all the downloads went well and all the requested files used a supported url schema, the script will return *0*. Otherwise will return *1*.
