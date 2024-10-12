# Supermicro Machine Setup

# Supermicro Machine Setup Runbook

This document outlines the steps to physically and logically set up a new Supermicro machine in the homelab.

## Physical Setup

### 1. Rack the Machine
- **Task**: Secure the server in the rack.

### 2. Labeling
- **Node Number**: Label the machine with its node number in the following format: `node##`.
  - Example: `node01`
- **Drive Serial**: Label the drive(s) with the last 3 digits of their serial number. 
  - Format: `###`
  - Example: If the serial number is `A1B2C3D456`, label the drive as `456`.

### 3. Network Connections
- **IPMI Network**: Connect the IPMI interface to the dedicated IPMI switch.
- **10GbE Network**: Connect the SFP+ NIC(s) to the 10GbE switch.

### 4. Power On
- **Task**: Plug in the power cable(s).

---

## IPMI Setup

### 1. Identify IP Address
- **Task**: Access the Unifi console at `192.168.1.1`.
- **IPMI Subnet**: Check for a new IP in the `192.168.10.*` subnet.
  - Example: If a new device appears, note the assigned IP address for the IPMI interface.

### 2. Log into IPMI
- **Task**: Open a web browser and enter the identified IPMI IP address.
- **Credentials**: 
  - **Username**: `ADMIN`
  - **Password**: `ADMIN` (default)

### 3. Change Network Configuration
- **Task**: Set the hostname for the IPMI interface.
  - Navigate to `Configuration > Network > Hostname`
  - Set the hostname to `node##` (replace `##` with the node number).
    - Example: For node `01`, set the hostname to `node01`.
  - **Access**: The IPMI interface will be available at `node##-ipmi.citadel.tomnowak.work`.
  - Example: `node01-ipmi.citadel.tomnowak.work`
  - **Save the configuration** after making changes.

### 4. Change Default Password
- **Task**: Update the default password for the `ADMIN` user.
  - Navigate to `Configuration > Users`
  - Select the `ADMIN` user and click **Modify User**.
  - Choose the option to **Change Password**.
  - Use NordPass to generate a secure password and enter it.
  - **Save** the changes to apply the new password.
  - **Note**: Store the new password securely.

### 5. Configure NTP Server
- **Task**: Enable and configure the NTP server to synchronize the system's time.
  - Navigate to `Configuration > Date and Time`
  - Enable **NTP**.
  - Enter the primary and secondary NTP servers for time synchronization.
    - **Primary NTP Server**: `0.pool.ntp.org`
    - **Secondary NTP Server**: `1.pool.ntp.org`
  - **Save** the configuration
