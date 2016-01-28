# -*- coding: utf-8 -*-

import requests
import time
import schedule

# The url of the data.
url = "http://opendata.paris.fr/explore/dataset/stations-velib-disponibilites-en-temps-reel/\
download/?format=csv&timezone=Europe/Berlin&use_labels_for_header=true"

def download_file():

    # Make the request.
    r = requests.get(url)

    # Get the current date and time.
    date_time = time.strftime("%Y-%m-%d_%Hh%M")
    
    # Save the csv file with the date and the time in the filename.
    with open("C:/Users/Thomas/Documents/R/velib/data/velib_" + date_time + ".csv", "wb") as code:
        code.write(r.content)

# Call the function every 15 minutes.
schedule.every(15).minutes.do(download_file)

while 1:
    schedule.run_pending()
    time.sleep(1)