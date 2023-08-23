#!/bin/bash

# Check that two parameters are passed
if [ $# -eq 2 ]; then
    # Check that the first parameter is one of the two possible: deny or delete
    if [ $1 == "deny" ] || [ $1 == "delete" ]; then
        # Assign the second parameter to the country_code variable
        country_code=$2
        
        # Check that the country code consists of two letters and conforms to the ISO 3166-1 alpha-2 standard
        if [[ $country_code =~ ^[a-z]{2}$ ]]; then
            # Download the file with IP addresses of the selected country from ipdeny.com
            wget http://www.ipdeny.com/ipblocks/data/countries/$country_code.zone
            
            # Check that the file was successfully downloaded and has a non-zero size
            if [ -s $country_code.zone ]; then
                # Depending on the first parameter, execute the corresponding command for UFW
                if [ $1 == "deny" ]; then
                    # Add rules to block IP addresses from the file
                    while read line; do sudo ufw deny from $line; done < $country_code.zone
                    echo "IP addresses from the file $country_code.zone were blocked using UFW."
                elif [ $1 == "delete" ]; then
                    # Delete rules to block IP addresses from the file
                    while read line; do sudo ufw delete deny from $line; done < $country_code.zone
                    echo "IP addresses from the file $country_code.zone were unblocked using UFW."
                fi
                
                # Delete the file with IP addresses
                rm $country_code.zone
                
            else
                # Print an error message when downloading the file
                echo "Failed to download the file with IP addresses for country $country_code."
            fi
            
        else
            # Print an error message when the country code is incorrect
            echo "Incorrect country code. The code must consist of two letters and conform to the ISO 3166-1 alpha-2 standard."
        fi
        
    else
        # Print an error message when the first parameter is incorrect
        echo "Incorrect first parameter. Valid parameters: deny or delete."
    fi
    
else
    # Print an error message when the number of parameters is incorrect and information on how to use the script
    echo "Incorrect number of parameters. You need to pass two parameters: deny or delete and country code."
    echo "Example of using the script: ./script.sh deny ch"
fi
