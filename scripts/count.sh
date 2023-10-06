#!/bin/bash
current_user=$(whoami)
delimiter=$(printf "*%.0s" {1..64})
echo "$delimiter"
echo "The script is running under the user: $current_user"
echo "Value of MY_ENV variable is: $MY_ENV"
echo "$delimiter"

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <end_number>"
    exit 1
fi

end_number=$1
count=0

while [ $count -le $end_number ]; do
    echo "Count: $count"
    ((count++))
    sleep 1
done

exit 0