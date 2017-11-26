#!/bin/bash

# Launch mongodb
sudo -u mongodb nohup mongod --smallfiles --logpath=/var/log/mongodb/mongodb.log &

# Run entrypoint.sh arguments
exec $@
