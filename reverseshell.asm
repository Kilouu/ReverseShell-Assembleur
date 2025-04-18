section .data
    ; IPV4 : domain=AF_INET (2)
    ; TCP : type=SOCK_STREAM (1)
    ; IP : protocol=TCP (0)

    socket_args dd 2,1,0

section .bss
    ip_input        resb 20     ; Buffer pour l'ip users
    port_input      resb 6      ; Buffer pour le port
    sockaddre_in    resb 16     ; Structure pour connect

section .text
    global _start


_start

    ;----------------------------------------------------------------------------
    ;-                                  IP                                      -
    ;----------------------------------------------------------------------------
    ; Message demande de l'IP

    ; Récupération IP
    mov eax, 3              ; syscall --> read pour lire l'entré Utilisateur
    mov ebx, 0              ; stdin --> Entré clavier
    mov ecx, ip_input       ; Zone mémoire ou stocké l'entrée utilisateur
    mov edx, 20             ; Max d'octet a lire
    int 0x80                ; Lance


    ;----------------------------------------------------------------------------
    ;-                                 PORT                                     -
    ;----------------------------------------------------------------------------
    ; Message demande du Port

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
    bswap eax               ; Inverse les octets pour le format réseau (big-endian)
    mov [port_input], ax    ; Stocke le port converti en hexadécimal



    mov eax, 102            ; syscall --> socketcall
    mov ebx, 1              ; sous fonction de syscall --> socket()
    lea ecx, [socket_args]  ; Pointe vers mon arguments
    int 0x80                ; Lance