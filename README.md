# Server Setup Scripts

A collection of scripts to simplify and standardize server setup and configuration for Debian/Ubuntu-based distributions. These scripts include:

- Initial server setup (user creation, SSH hardening, basic package installation, UFW configuration)
- WireGuard installation and configuration
- AdGuard Home installation and configuration
- NextDNS setup
- ...and more to come!

## Prerequisites

- Debian/Ubuntu-based distribution (tested primarily on Ubuntu 20.04 or 22.04 LTS)
- Root access or a user with `sudo` privileges

## Getting Started

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

---

## Exemple de README dédié au script `init-server.sh`

Si tu souhaites documenter chaque script dans un fichier séparé (par exemple dans un dossier `scripts/init-server/README.md`), voici un exemple :

```markdown
# init-server.sh

A Bash script for initial server setup on Debian/Ubuntu, including:

1. **User creation**  
   Prompts for a new username and password, adds the user to the `sudo` group.
2. **System update**  
   Runs `apt update && apt upgrade -y` to ensure your system is up to date.
3. **Basic packages installation**  
   Installs essential packages like `vim`, `zip`, `curl`, `net-tools`, `htop`, `git`, etc.
4. **Vim configuration**  
   Copies a `.vimrc` file with syntax highlighting, mouse disabled, etc.
5. **SSH hardening**  
   Disables root login and ensures password authentication is enabled (you can tweak this as needed).
6. **UFW firewall configuration**  
   Denies all incoming traffic except SSH and allows all outgoing traffic, then enables UFW.

## Usage

1. Make the script executable:
    ```bash
    chmod +x init-server.sh
    ```
2. Run the script as `root` or with `sudo`:
    ```bash
    sudo ./init-server.sh
    ```
3. Follow the prompts to create the new user.

## Notes

- The script checks if it’s run as root. If not, it exits immediately.
- Updates the system automatically; ensure there are no pending critical updates or issues before running.
- You can customize the list of installed packages and the `.vimrc` to meet your preferences.

---

Avec ces éléments, tu as un **README** principal en anglais et un **README** spécifique pour le script `init-server.sh`. Tu pourras bien sûr tout personnaliser selon l’évolution de tes besoins et l’ajout de nouveaux scripts. 

Bon courage pour la suite de la configuration et la mise en place de ton repository GitHub !

