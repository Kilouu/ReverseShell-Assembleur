# Reverse Shell en Assembleur x86 (32-bit)

## 📋 Description

Ce projet implémente un reverse shell écrit entièrement en assembleur x86 32-bit pour les systèmes Linux. Le programme établit une connexion TCP vers un serveur distant et redirige les entrées/sorties standard vers cette connexion, permettant l'exécution de commandes à distance.

## 🎯 Fonctionnalités

- ✅ **Saisie interactive** : Demande à l'utilisateur l'adresse IP et le port de destination
- ✅ **Validation d'IP** : Vérification de la validité de l'adresse IPv4 saisie
- ✅ **Reconnexion automatique** : Réessaie la connexion toutes les 5 secondes en cas d'échec
- ✅ **Shell interactif** : Lance un shell bash avec support PTY pour une expérience complète
- ✅ **Redirection I/O** : Redirige stdin, stdout et stderr vers la connexion réseau

## 🛠️ Compilation et Exécution

### Prérequis
- Système Linux (32-bit ou 64-bit avec support 32-bit)
- NASM (Netwide Assembler)
- ld (GNU Linker)

### Compilation
```bash
# Assemblage du code source
nasm -f elf32 reverseshell.asm -o reverse_shell.o

# Édition de liens
ld -m elf_i386 reverse_shell.o -o reverse_shell
```

### Exécution
```bash
# Rendre le fichier exécutable
chmod +x reverse_shell

# Lancer le programme
./reverse_shell
```

## 🔧 Utilisation

1. **Lancement du programme** : Exécutez le binaire compilé
2. **Saisie de l'IP** : Entrez l'adresse IP du serveur d'écoute (ex: 192.168.1.100)
3. **Saisie du port** : Entrez le port d'écoute (ex: 4444)
4. **Connexion** : Le programme tente de se connecter automatiquement

### Côté serveur (machine d'écoute)
```bash
# Exemple avec netcat
nc -lvp 4444

# Exemple avec socat
socat TCP-LISTEN:4444,reuseaddr,fork -
```

## 📊 Architecture du Code

### Structure des sections

#### `.data` - Données initialisées
- `socket_args` : Arguments pour la création du socket (AF_INET, SOCK_STREAM, TCP)
- Messages d'interface utilisateur (prompts, erreurs)
- Configuration du shell et commandes
- Structure `timespec` pour les délais de reconnexion

#### `.bss` - Données non initialisées
- `ip_input` : Buffer pour l'adresse IP utilisateur (20 octets)
- `port_input` : Buffer pour le port (6 octets)
- `sockaddre_in` : Structure sockaddr_in pour la connexion (16 octets)

#### `.text` - Code exécutable
- Validation et parsing de l'adresse IP
- Conversion du port en format réseau
- Création et configuration du socket
- Boucle de reconnexion avec délai
- Redirection des descripteurs de fichiers
- Lancement du shell interactif

### Flux d'exécution

```
1. Demande et validation de l'IP utilisateur
2. Demande et conversion du port
3. Création du socket TCP
4. Tentative de connexion (avec retry automatique)
5. Redirection stdin/stdout/stderr vers le socket
6. Lancement de /bin/sh avec support PTY
```

## 🔍 Détails Techniques

### Appels Système Utilisés
- `write` (4) : Affichage des messages
- `read` (3) : Lecture des entrées utilisateur  
- `socketcall` (102) : Création socket et connexion
- `nanosleep` (162) : Délai entre tentatives de connexion
- `dup2` (63) : Redirection des descripteurs de fichiers
- `execve` (11) : Lancement du shell

### Validation d'IP
Le programme implémente un parser d'adresse IPv4 complet qui :
- Vérifie que chaque octet est dans la plage 0-255
- Valide le format avec exactement 3 points séparateurs
- Gère les erreurs de saisie avec demande de ressaisie

### Gestion d'Erreurs
- **IP invalide** : Message d'erreur et nouvelle demande
- **Connexion échouée** : Retry automatique toutes les 5 secondes
- **Validation des entrées** : Vérification des formats et plages