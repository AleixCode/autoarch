# AutoArch

## Prerequisites

### Newtork Connection

In order to be able to run this script you require to have network connection.
If you're on ethernet there's no need to do anything, in case you are going wireless you should run this commands:

1. Open the interactive `iwctl` utility:

   iwctl

2. List available network devices and choose the one you want to connect with (e.g., `wlan0`):

   device list

3. Activate the chosen interface (`wlan0`) to start scanning for networks:

   station `wlan0` scan

4. View a list of available networks:

   station `wlan0` get-networks

5. Identify the network you want to connect to (let's call it `net0`).

6. Connect to the selected network (`net0`). If the network is secured, a prompt will appear to enter the passphrase:

   station `wlan0` connect `net0`

   Note: The connection process might take a while.

Feel free to replace `wlan0` and `net0` with your specific interface and network names.

### UEFI

   Enable boot into UEFI (e.g, https://neosmart.net/wiki/enable-uefi-boot/)

## Installing

1. Download the script
   curl -LO https://raw.githubusercontent.com/AleixCode/autoarch/refs/heads/main/installer.sh
   
## Usage

1. Make the script executable
   chmod +x installer.sh

2. Run the script
   ./installer.sh

