if [[ "$OSTYPE" == "linux-gnu" ]]; then
    # run linux stuff here

    elif [[ "$OSTYPE" == "darwin"* ]]; then
    # run mac stuff here
else
    echo "os not supported by this install script"
fi