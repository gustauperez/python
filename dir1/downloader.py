#!/usr/bin/env python3

import argparse
import boto3
import ftplib
import os.path
import sys
import threading
from urllib.request import urlretrieve
from urllib.parse import urlparse

class ownParser(argparse.ArgumentParser):
    def error(self, message):
        sys.stderr.write('error: %s\n\n' % message)
        self.print_help()
        sys.exit(1)

def downloaderFTP(resource, file_name, results):
    path        = resource[0]
    urlparsed   = resource[1]
    try:
        ftp = ftplib.FTP(urlparsed.netloc)
        ftp.login()
        ftp.cwd(os.path.split(urlparsed.path)[0])
        ftp.retrbinary("RETR " + urlparsed.path ,open(file_name, 'wb').write)
        ftp.quit()
        results.update({file_name:"Ok"})
    except Exception:
        results.update({file_name:"Ko"})

def downloaderS3(resource, file_name, results):
    path        = resource[0]
    urlparsed   = resource[1]
    print("About to download: " + file_name + " with: " + urlparsed.scheme)
    try:
        s3 = boto3.resource('s3')
        s3.Bucket(urlparsed.netloc).download_file(urlparsed.path[1:], file_name)
        results.update({file_name:"Ok"})
    except Exception:
        results.update({file_name:"Ko"})

# First argument is a pair of [url, urlparsed], the second is the final filename we want and
# the third is a hash we're gonna store the result of the download
def downloaderHttp(resource, file_name, results):
    path        = resource[0]
    urlparsed   = resource[1]
    print("About to download: " + file_name + " with: " + urlparsed.scheme)
    try:
        urlretrieve(path, file_name)
        results.update({file_name:"Ok"})
    except Exception:
        results.update({file_name:"Ko"})

schemes = {"http": downloaderHttp,
           "https": downloaderHttp,
           "s3": downloaderS3,
           "ftp": downloaderFTP
}

# The main rutine will put into a hash table (dictionary) the names of the files to download as the key (to prevent the download
# of the same file more than twice, the last one will take precedence. As the value we'ill put a tuple of the passed url and
# the correspoding parsed url object (using urlparse).
#
# Also, to make the script easy to maintain, we have another hash table called schemes that contains all the protocols supported
# and the correspoing routine that will handle the download. That way we can spawn a thread to handle the download and the routine
# that the thread will run can be easily found in the schemes hash table.
#
# Finally, we don't need to use semaphore to protect the results hash since those basic Python structures are thread-safe
if __name__ == '__main__':
    files_to_download = {}
    results           = {}
    threads           = []
    exit_code         = 0

    parser = ownParser(description='Downloads a bunch of urls. The schemes supported are: '+' '.join(map(str, schemes.keys())))
    parser.add_argument('-u', '--url', nargs='+', default=[], required=True)

    args=parser.parse_args()

    if args.url:
        for value in args.__dict__["url"]:
            try:
                o = urlparse(value)
                if schemes.get(o.scheme) and o.path != "" and o.path != "/":
                    files_to_download.update({os.path.split(o.path)[1]:[value, o]})
            except:
                print("Wrong url: " + value, sys.exc_info()[0])
                sys.exit(1)

        for key in files_to_download:
            t = threading.Thread(target=schemes.get(files_to_download.get(key)[1].scheme), args=(files_to_download.get(key), key, results))
            threads.append(t)
            t.start()

        for x in threads:
            x.join()

        for key in results:
            print("### File: " + key + " from: "+files_to_download.get(key)[0] + " downloaded with status: " + results.get(key))
            if results.get(key) == "Ko":
                exit_code = 1

        sys.exit(exit_code)