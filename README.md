# Server Setup Scripts

A collection of scripts to simplify and standardize server setup and configuration for Debian/Ubuntu-based distributions. These scripts include:

- **init-server.sh**: Initial server setup (user creation, SSH hardening, basic package installation, UFW firewall)
- **wireguard-setup.sh**: (Coming soon) WireGuard installation and configuration
- **adguardhome-setup.sh**: (Coming soon) AdGuard Home installation and configuration
- **nextdns-setup.sh**: (Coming soon) NextDNS setup
- ...and more to come!

## Prerequisites

- Debian/Ubuntu-based distribution (tested primarily on Ubuntu 20.04 or 22.04 LTS)
- Root access or a user with `sudo` privileges

## Quick Start

If you want to **quickly run the initial server setup script** (`init-server.sh`) from this repository, use:

```bash
curl -s -S -L https://raw.githubusercontent.com/idem2lyon/server-setup-scripts/main/init-server.sh | sh -s -- -v
```
    Note:

        The -s flag makes curl silent.
        The -S flag shows errors (if any).
        The -L flag follows redirects.
        Piping directly to sh executes the script. Use at your own risk and always verify scripts before running them if security is a concern.

Alternatively, you can  : 

1. **Clone the repository**:
    ```bash
    git clone https://github.com/<your-username>/server-setup-scripts.git
    ```
2. **Navigate to the cloned directory**:
    ```bash
    cd server-setup-scripts
    ```
3. **Make the desired script executable and run it** (for example, `init-server.sh`):
    ```bash
    chmod +x init-server.sh
    sudo ./init-server.sh
    ```
    > Make sure you run the script as root or use `sudo`.

## Available Scripts

1. **init-server.sh**  
   Sets up a new user, installs basic packages, configures Vim, hardens SSH settings, and enables UFW.

2. **wireguard-setup.sh** *(coming soon)*  
   Installs and configures WireGuard.

3. **adguardhome-setup.sh** *(coming soon)*  
   Installs and configures AdGuard Home.

4. **nextdns-setup.sh** *(coming soon)*  
   Sets up NextDNS.

Feel free to add your own scripts or adapt these to suit your needs.

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository.
2. Create a new branch for your feature or fix:
    ```bash
    git checkout -b feature/your-new-feature
    ```
3. Commit your changes:
    ```bash
    git commit -m "Add a new feature"
    ```
4. Push your branch to GitHub:
    ```bash
    git push origin feature/your-new-feature
    ```
5. Open a Pull Request on this repository.

## License

This project is licensed under the [MIT License](./LICENSE). Feel free to use and modify these scripts as you see fit.


