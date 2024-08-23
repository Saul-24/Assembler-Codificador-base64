.data
ArchivoN_prompt:    .asciiz "Ingrese la ruta del archivo a codificar: "
success_message:    .asciiz "Archivo codificado exitosamente como codificado.txt."
buffer:             .space  256         # Búfer para la ruta del archivo almacenada en 256
buffer_in:          .space  11853        # Búfer para el contenido del archivo de entrada es el maximo que encontre para para la entrada y que no desborda
buffer_out:         .space  16000        # Búfer para la salida codificada (16000 * 4/3, con relleno) max
Archivo_Codificado: .asciiz "codificado.txt"
base64_table:       .asciiz "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
debug_message:      .asciiz "Debug: "
error_message:      .asciiz "Error: No se pudo abrir el archivo ingrese una ruta correcta :) \n"
bytes_read_message: .asciiz " bytes leídos.\n"
bytes_encoded_message: .asciiz " bytes codificados.\n"

.text
.globl main

main:
    # Solicitar al usuario la ruta del archivo
    li      $v0, 4             
    la      $a0, ArchivoN_prompt
    syscall

    # Leer la ruta del archivo del usuario
    li      $v0, 8             
    la      $a0, buffer
    li      $a1, 256           
    syscall

    # Eliminar el carácter de nueva línea de la entrada. Importante por el carcter que hace el user al dar enter y se crea un salto de linea
    la      $t0, buffer
    li      $t1, 0
remove_newline:
    lb      $t2, 0($t0)
    beq     $t2, $zero, open_file
    beq     $t2, '\n', newline_removed  #o puedes 0x0A
    addi    $t0, $t0, 1
    j       remove_newline

newline_removed:
    sb      $zero, 0($t0)

open_file:
    # Abrir el archivo
    li      $v0, 13            
    la      $a0, buffer
    li      $a1, 0             
    li      $a2, 0            
    syscall
    bltz    $v0, file_open_error
    move    $s0, $v0           

    # Leer contenido del archivo
    li      $v0, 14            
    move    $a0, $s0            
    la      $a1, buffer_in
    li      $a2, 11853                    
    syscall
    move    $s1, $v0          
    bltz    $s1, file_read_error

    # Cerrar el archivo
    li      $v0, 16            
    move    $a0, $s0           
    syscall

    # Imprimir número de bytes leídos (debug)
    li      $v0, 4             
    la      $a0, debug_message
    syscall

    li      $v0, 1             
    move    $a0, $s1          
    syscall

    li      $v0, 4             
    la      $a0, bytes_read_message
    syscall

    # Codificar contenido a Base64
    la      $a0, buffer_in     
    move    $a1, $s1           
    la      $a2, buffer_out     

    # Llamar a la subrutina de codificación
    jal     codificar_base64

    # Guardar la longitud de la salida codificada
    move    $s2, $v0

    # Imprimir número de bytes codificados (debug) :)
    li      $v0, 4             
    la      $a0, debug_message
    syscall

    li      $v0, 1              
    move    $a0, $s2           
    syscall

    li      $v0, 4              
    la      $a0, bytes_encoded_message
    syscall

    # Escribir contenido codificado en un nuevo archivo (codificado.txt)
    # Abrir archivo para escribir
    li      $v0, 13            
    la      $a0, Archivo_Codificado 
    li      $a1, 1              
    li      $a2, 0             
    syscall
    bltz    $v0, file_open_error
    move    $s0, $v0            

    # Escribir contenido codificado en el archivo
    li      $v0, 15             
    move    $a0, $s0           
    la      $a1, buffer_out    
    move    $a2, $s2           
    syscall

    # Cerrar archivo
    li      $v0, 16          
    move    $a0, $s0            
    syscall

    # Mostrar mensaje de éxito
    li      $v0, 4             
    la      $a0, success_message
    syscall

    # Salir del programa
    li      $v0, 10             
    syscall

file_open_error:
    li      $v0, 4              
    la      $a0, error_message
    syscall
    li      $v0, 10            
    syscall
#Manejo de errores
file_read_error:
    li      $v0, 4             
    la      $a0, error_message
    syscall
    li      $v0, 10             
    syscall
##########################################

#########################################

#########################################
# Subrutina para codificar datos a Base64

codificar_base64:
    move    $t0, $a0       
    move    $t1, $a1       
    move    $t2, $a2       
    move    $t3, $zero     

    la      $t8, base64_table

codificar_base64_loop:
    # Comprobar si quedan bytes por procesar
    bge     $t3, $t1, codificar_base64_done

    # Leer 3 bytes del búfer de entrada, manejar relleno si es necesario
    lb      $t4, 0($t0)
    addi    $t0, $t0, 1
    addi    $t3, $t3, 1
    lb      $t5, 0($t0)
    addi    $t0, $t0, 1
    addi    $t3, $t3, 1
    lb      $t6, 0($t0)
    addi    $t0, $t0, 1
    addi    $t3, $t3, 1

    # Manejar relleno
    blt     $t3, $t1, Codificar_Noespacios 

    # Manejar en caso cuando estamos cerca del final y puede necesitarse relleno ==
    bgt     $t3, $t1, codificar_un_byte_izquierda 

Codificar_Noespacios:
    # Primer byte: bits 7-2
    andi    $t7, $t4, 0xFC
    srl     $t7, $t7, 2

    # Segundo byte: bits 1-0 de t4 y bits 7-4 de t5
    andi    $t9, $t4, 0x03
    sll     $t9, $t9, 4
    andi    $s0, $t5, 0xF0
    srl     $s0, $s0, 4
    or      $t9, $t9, $s0

    # Tercer byte: bits 3-0 de t5 y bits 7-6 de t6
    andi    $s0, $t5, 0x0F
    sll     $s0, $s0, 2
    andi    $s1, $t6, 0xC0
    srl     $s1, $s1, 6
    or      $s0, $s0, $s1

    # Cuarto byte: bits 5-0 de t6
    andi    $s1, $t6, 0x3F

    # Mapear los valores a caracteres Base64
    addu    $t7, $t8, $t7
    lb      $t7, 0($t7)

    addu    $t9, $t8, $t9
    lb      $t9, 0($t9)

    addu    $s0, $t8, $s0
    lb      $s0, 0($s0)

    addu    $s1, $t8, $s1
    lb      $s1, 0($s1)

    # Guardar los caracteres Base64 en el búfer de salida
    sb      $t7, 0($t2)
    sb      $t9, 1($t2)
    sb      $s0, 2($t2)
    sb      $s1, 3($t2)
    addi    $t2, $t2, 4

    # Bucle para el siguiente conjunto de 3 bytes
    j       codificar_base64_loop

codificar_un_byte_izquierda:
    # Caso especial: 1 byte restante por procesar
    blt     $t3, $t1, codificar_dos_byte_izquierda  

    # Primer byte: bits 7-2
    andi    $t7, $t4, 0xFC
    srl     $t7, $t7, 2

    # Segundo byte: bits 1-0 de t4 y relleno
    andi    $t9, $t4, 0x03
    sll     $t9, $t9, 4

    # Tercer y cuarto byte son '=' (relleno)
    li      $s0, '='
    li      $s1, '='

    # Mapear los valores a caracteres Base64
    addu    $t7, $t8, $t7
    lb      $t7, 0($t7)

    addu    $t9, $t8, $t9
    lb      $t9, 0($t9)

    # Guardar los caracteres Base64 en el búfer de salida
    sb      $t7, 0($t2)
    sb      $t9, 1($t2)
    sb      $s0, 2($t2)
    sb      $s1, 3($t2)
    addi    $t2, $t2, 4

    j      codificar_base64_done

codificar_dos_byte_izquierda:
    # Caso especial: 2 bytes restantes por procesar
    # Primer byte: bits 7-2
    andi    $t7, $t4, 0xFC
    srl     $t7, $t7, 2

    # Segundo byte: bits 1-0 de t4 y bits 7-4 de t5
    andi    $t9, $t4, 0x03
    sll     $t9, $t9, 4
    andi    $s0, $t5, 0xF0
    srl     $s0, $s0, 4
    or      $t9, $t9, $s0

    # Tercer byte: bits 3-0 de t5
    andi    $s0, $t5, 0x0F
    sll     $s0, $s0, 2

    # Cuarto byte es '=' el relleno 
    li      $s1, '='

    # Mapear los valores a caracteres Base64
    addu    $t7, $t8, $t7
    lb      $t7, 0($t7)

    addu    $t9, $t8, $t9
    lb      $t9, 0($t9)

    addu    $s0, $t8, $s0
    lb      $s0, 0($s0)

    # Guardar los caracteres Base64 en el búfer de salida
    sb      $t7, 0($t2)
    sb      $t9, 1($t2)
    sb      $s0, 2($t2)
    sb      $s1, 3($t2)
    addi    $t2, $t2, 4

    j      codificar_base64_done

codificar_base64_done:
    sub     $v0, $t2, $a2   
    jr      $ra              
