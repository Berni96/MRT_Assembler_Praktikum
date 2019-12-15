/*
 * Blinklib_lib.S
 *
 *  Created on: 08.12.2019
 *      Author: mrt
 */

.equ 	BCM2836_PERI_BASE,			0x3f000000		//Adresse, an der die Peripherie-register beginnen

.equ	BCM2836_GPIO_BASEOFFSET,	0x00200000		//Offset von der Peripheriebasis, ab dem die GPIO Register beginnen
.equ	BCM2836_GPIO_LASTADRESS, 	0x002000B4		//Offset, an dem die GPIOregister enden
.equ	BCM2836_GPIO_MEMSIZE,		0x00001000		//Größe der GPIOsektion -> mindestens 4k Adressen, da memorymap nur mit 4k Blöcken arbeitet
.equ 	BCM2836_GPIO_BASE, 			BCM2836_PERI_BASE + BCM2836_GPIO_BASEOFFSET		//Beginn der GPIO-Register im Peripheriebereich

.equ	BCM2836_OFFSET_GPIO_SET,	28				//Offset des Registers GPSET0 von der GPIO_Basis = GPFSEL0-Register
.equ	BCM2836_OFFSET_GPIO_CLR,	40				//Offset des Registers GPCLR0 von der GPIO_Basis = GPFSEL0-Register
.equ	BCM2836_OFFSET_GREN,		76				//Offset des Registers GREN0 von der GPIO_Basis = GPFSEL0-Register
.equ	BCM2836_OFFSET_GPED,		64				//Offset des Registers GPED0 von der GPIO_Basis = GPFSEL0-Register


.equ 	OPEN_PARAMETER_SYNC_RDWR, 		0x00101002	//Parameter, die für die Syscalls benötigt werden -> aus Vorlesung übernommen
.equ 	MMAP_PARAMETER_PROT_READ_WRITE, 0x03		//  .
.equ 	MMAP_PARAMETER_MAP_SHARED, 		0x01		//  .

.equ	SYSCALL_OPEN,				5				//Syscallnummer für "open"
.equ	SYSCALL_CLOSE,				6				//Syscallnummer für "close"
.equ	SYSCALL_MMAP2,				192				//Syscallnummer für "mmap2"
.equ	SYSCALL_MUNMAP,				91				//Syscallnummer für "munmap"

//Alle Funktionen die auch außerhalb dieses Sourcecodes aufgerufen werden können
.globl calc_offset, open, close, gpio_fsel, gpio_set, gpio_clr, r_flank_enable, read_button, button_clr

//Sektion für Variablen
.data
.balign 4
dev_mem_filename:	.asciz			"/dev/mem"		//Variable für den Namen der /dev/memdatei
dev_mem_gpio_fd:	.word			0				//Variable für den von /dev/mem beim öffnen zurückgegebenen filehandle
mmap2_baseadress:	.word			0				//Variable für Basisadresse von Memorymapping

.text

/*
	INPUT:	r0 = GPIOnumber

Diese Funktion setzt für den in Register r0 übergebenen  GPIO im Register GREN eine 1,
sodass dieser GPIO für jede steigende Flanke, die an ihm abfällt, sein Bit im GPED-register
auf 1 setzt. Die eins aus GPED kann ausgelesen werden, um zu erfahren, ob der Knopf am GPIO
gedrückt wurde.

*/
.func r_flank_enable
r_flank_enable:	mov 	ip, sp						//EABI
				stmfd	sp!,{r4-r11,lr}
				mov 	fp, ip

				mov 	r1, #BCM2836_OFFSET_GREN	//In Register r1 den Offset von Register GREN0 laden

				mov		r9, r1						//Den Offset in Register r9 speichern

				mov		r1, #0						//Offset von GREN auf 0 setzen

loop_flank:		sub  	r0, r0, #32					//Offset und dem GPIO entsprechende Bitnummer berechnen
				cmp 	r0, #0
				blt		endloop_flank
				add		r1, r1, #1
				b		loop_flank
endloop_flank:	add		r0, r0, #32

				mov		r4, r0						//Berechnete Bitnummer in r4 speichern
				mov		r5, r1						//Offset von GREN0 in r5 speichern

				lsl		r5, #2						//Offset von GREN0 mit 4 multiplizieren und auf Offset von GPFSEL aufaddieren
				add		r5, r5, r9

				ldr		r0, =mmap2_baseadress		//Memorymapbasisadresse öffnen und Gesamtoffset aufaddieren
				ldr		r0, [r0]
				add		r0, r0, r5

				ldr		r2, [r0]					//Memorymap-offset in Register r2 speichern

				mov 	r1, #0b1					//Maske bilden und zu GPIO ensprechenden Bit verschieben
				lsl		r1, r4
				orr		r1, r1, r2					//Mit "oder" eine 1 in das entsprechende Bit schreiben
				str		r1,[r0]						//den geänderten Inhalt wieder ins das GRENregister speichern

				ldmfd	sp!,{r4-r11,lr}				//EABI
				bx 		lr
.endfunc



/*
	INPUT:	r0 = GPIOnumber		OUTPUT:	r0 = Status: 1 if pressed, 0 if not pressed

Diese Funktion liest im GPED-register das Bit, das dem im Register r0 übergebenen  GPIO entspricht aus.
Liegt hier eine 0, hat der GPIO keine Flanke detektiert: -> Taster wurde nicht gedrückt
Liegt hier eine 1, hat der GPIO eine Flanke detektiert:	 -> Taster wurde gedrückt
*/
.func read_button
read_button:	mov 	ip, sp						//EABI
				stmfd	sp!,{r4-r11,lr}
				mov 	fp, ip

				mov		r1, #0						//Offset von GPED0 auf 0 setzen

loopreadbut:	sub  	r0, r0, #32					//Offset und dem GPIO entsprechende Bitnummer berechnen
				cmp 	r0, #0
				blt		endloopreadbut
				add		r1, r1, #1
				b		loopreadbut
endloopreadbut:	add		r0, r0, #32

				mov		r4, r0						//Bitnummer in r4 speichern
				mov		r5, r1						//Offset von GPED0 in r5 speichern
				lsl		r5, #2
				add		r5, r5, #BCM2836_OFFSET_GPED//Den Offset von GPED0 zum Offset des GPED0 von der Basisadresse addieren

				ldr		r0, =mmap2_baseadress		//Memorymapbasisadresse in r0 laden
				ldr		r0, [r0]
				add		r0, r0, r5					//Gesamtoffset auf die Basisadresse addieren
				ldr		r0, [r0]					//Den Inhalt dieser Adresse laden

				mov 	r1, #0b1					//Maske bilden und unter das dem GPIO entsprechende Bit verschieben
				lsl		r1, r4
				and		r0, r0, r1					//Bit mit "und" auslesen und wieder die 0te Bitstelle verschieben
				lsr		r0, r4						//Jetz steht in r0, was in dem GPIO bit steht

				ldmfd	sp!,{r4-r11,lr}				//EABI
				bx 		lr
.endfunc


/*
	INPUT: r0 = GPIO number
Diese Funktion schreibt in das GPED register in das dem GPIO entsprechende Bit eine 1. Durch das hineinschreiben einer 1 wird das
GPED register gelöscht. Dafür kann die Funktion set_clr verwendet werden, da hier in die anderen Bits zwar eine 0 geschrieben wird,
das GPED register aber nur auf gschriebene 1er reagiert.
*/
.func button_clr
button_clr:		mov 	ip, sp						//EABI
				stmfd	sp!, {r4-r11,lr}
				mov		fp, ip

				mov		r1, #BCM2836_OFFSET_GPED	//den Offset für das GPED-register in r1 laden

				bl		set_clr						//das dem GPIO entsprechende Bit mit der Funktion set_clr setzen

				ldmfd	sp!, {r4-r11,lr}			//EABI
				bx 		lr
.endfunc
/* INPUT:	r0 = GPIOnumber		OUTPUT:	r0 = Baseoffset
										r1 = Bitfieldnumber

Diese Funktion berechnet, wie viele Register von GPFSEL noch weiter gegangen werden müssen, um das zu erreichen, das mein
gewünschtes GPIO enthält, sowie die die Nummer des entsprechenden Bits in diesem GPFSEL-register.
Diese Funktion wird benötigt, da bei GPFSEL drei statt einem Bit für einen GPIO stehen und somit die Funktion set_clr nicht
passt.

Die Funktion ist nur innerhalb der Funktionssammlung aufrufbar.
*/
.func calc_offset
calc_offset:	mov 	ip, sp						//EABI
				stmfd	sp!,{r4-r11,lr}
				mov 	fp, ip

				mov 	r1, r0						//spichern der GPIOnummer in R0
				mov 	r0, #0						//den Offset von der GPFSEL-basisadresse auf null stellen

modulo:			sub 	r1, r1, #10					//modulo berechnung mit Divident 10
				cmp		r1, #0
				blt		endmodulo
				add		r0, r0, #1
				b		modulo
endmodulo: 		add		r1, r1, #10					//ab hier steht in r0 der Offset und in r1 die Bitnummer

				ldmfd	sp!,{r4-r11,lr}				//EABI
				bx 		lr
.endfunc

/* INPUT:	r0 = GPIOnumber							//
			r1 = GPIOfunctionnumber

Diese Funktion Stellt für den in Register r0 übergebenen GPIO die in Register r1 übergebene Funktion ein.
So kann ein GPIO zu einem Output, INPUT, oder einer alternativen Funktion gemacht werden.
*/
.func gpio_fsel
gpio_fsel:		mov 	ip, sp						//EABI
				stmfd	sp!,{r4-r11,lr}
				mov		fp, ip

				mov		r4,	r1						//Funktionsnummer in r4 speichern
				bl		calc_offset					//mit Funktion calc_offset die Position des zu ändernden GPIOs in GPFSEL berechnen

				mov 	r5, r0						//Offset von der GPFSEL-Basisadresse in r5 speichern

				ldr		r0, =mmap2_baseadress		//die vom Memorymapping übergebene Basisadresse in r0 laden
				ldr		r0, [r0]
				add 	r0, r0, r5, lsl #2			//den Offset mit 4 multiplizieren und auf Memorymap-basisadresse addieren

				mov		r9, r0						//Adresse, die das zu ändernde Bit enthält in r9 zwischenspeichern

				mov 	r6, r1						//Die Nummer des zu ändernden Bits mit 3 multiplizieren und in r6 speichern
				lsl		r1, #1
				add		r6,	r6, r1

				//copy,modify, update
				ldr		r0, [r9]					//Inhalt der Andress mit dem zu ändernden Bit in r0 laden
				mov		r1,	#0b111					//Maske zum löschen der GPIO-funktion erstellen
				bic		r0, r0, r1, lsl r6			//Maske bis zu GPIO ensprechenden Bits verschieben und diese mit bic auf null setzen
				orr		r0,	r0, r4, lsl r6			//Gewünschte Funktion in die Bits des GPIOS schreiben
				str		r0, [r9]					//Die den geänderten Inhalt zurück ins Register GPFSEL speichern

				ldmfd	sp!,{r4-r11,lr}				//EABI
				bx		lr

.endfunc

/*
	INPUT:	r0 = GPIOnumber
			r1 = OFFSET

Diese Funktion ist ausgelagert, da sie von mehreren anderen Funktionen genutzt wird (gpio_set, gpio_clr).
Ihr wird in Register r0 der zu ändernde GPIO und in Register r1 der Offset zum zu ändernden Register übergeben.
Dann wird die genaue Position des Bits im Register und wie viele Register man weiter gehen muss berechnet.
In das entsprechende Bit wird eine geschrieben.

Die Funktion wird nur intern in der Funktionssammlung verwendet
*/

.func set_clr
set_clr:		mov 	ip, sp						//EABI
				stmfd	sp!,{r4-r11,lr}
				mov 	fp, ip

				mov	r9, r1							//Übergebenen Offset in r9 speichern

				mov		r1, #0						//Offset von entsprechenden Register auf 0 setzen

loop_setclr:	sub  	r0, r0, #32					//Offset und Nummer des entsprechenden GPIOs im Register berechnen
				cmp 	r0, #0
				blt		endloop_setclr
				add		r1, r1, #1
				b		loop_setclr
endloop_setclr:	add		r0, r0, #32

				mov		r4, r0						//Bitnummer in Register r4 speichern
				mov		r5, r1						//Offset von entsprechendem Register in R5 speichern
				lsl		r5, #2						//Offset mit 4 multiplizieren und auf übergebenen Offset aufaddieren
				add		r5, r5, r9

				ldr		r0, =mmap2_baseadress		//Memorymap basisadresse öffnen und Geamtoffset aufaddieren
				ldr		r0, [r0]
				add		r0, r0, r5

				mov 	r1, #0b1					//Maske bilden und unter GPIO entsprechendes Bit verschieben
				lsl		r1, r4
				str		r1,[r0]						//geänderten Wert zurück in das Register schreiben

				ldmfd	sp!, {r4-r11,lr}			//EABI
				bx 		lr
.endfunc

/*
	INPUT:	r0 = GPIONumber

Diese Funktion setzt im GPSET-register das, dem in Register r0 übergebenen GPIO entsprechende,Bit auf 1.
So wird die am GPIO anliegende Spannung auf eins gesetzt.
Hierfür wird in Register 1 der Offset für GPSET geladen und das setzen mit der Funktion set_clr ausgeführt.
*/
.func gpio_set
gpio_set:		mov 	ip, sp						//EABI
				stmfd	sp!, {r4-r11,lr}
				mov		fp, ip

				mov		r1, #BCM2836_OFFSET_GPIO_SET//GPSET0 Offset von GPFSEL in R1 speichern

				bl		set_clr						//schreiben einer 1 in das dem GPIO entsprechende Bit mit Funktion set_clr

				ldmfd	sp!, {r4-r11,lr}			//EABI
				bx 		lr
.endfunc

/*
	INPUT:	r0 = GPIOnumber

Diese Funktion setzt im GPCLR-register das, dem in Register r0 übergebenen GPIO entsprechende,Bit auf 1.
So wird die am GPIO anliegende Spannung auf null gesetzt.
Hierfür wird in Register 1 der Offset für GPCLR geladen und das setzen mit der Funktion set_clr ausgeführt.
*/
.func gpio_clr
gpio_clr:		mov 	ip, sp						//EABI
				stmfd	sp!, {r4-r11,lr}
				mov		fp, ip

				mov		r1, #BCM2836_OFFSET_GPIO_CLR//GPCLR0 Offset von GPFSEL in R1 speicher

				bl		set_clr						//schreiben einer 1 in das dem GPIO entsprechende BIT mit Funktion set_clr

				ldmfd	sp!, {r4-r11,lr}			//EABI
				bx 		lr

.endfunc

/*
Diese Funktion öffnet die Datei /dev/mem und führt anschließend ein memory mapping durch,
um die Peripherie in der Datei /dev/memm abzubilden. Die Basisadresse, die das Memorymapping in Register r0 zurückgibt
wird in der Variable mmap2_baseadress zur späteren Verwendung gespeichert.
*/
.func open
open:			mov		ip, sp						//EABI
				stmfd	sp!,{r4-r11,lr}
				mov 	fp, ip

				//Open devmem
				ldr		r0, =dev_mem_filename		//Übergeben der für den Syscall "open" benötigten Parameter in den entsprechenden Registern
				ldr		r1, =OPEN_PARAMETER_SYNC_RDWR
				mov		r2, #0
				mov		r7, #SYSCALL_OPEN
				swi		#0							//Ausführen von Softwareinterrupt
				ldr		r1, =dev_mem_gpio_fd		//Speichern des von "open" in Register 0 zurückgegebenen filehandels in der Variable "dev_mem_gpio_fd"
				str		r0, [r1]


				//Memorymapping
				mov 	r0, #0						//Übergeben der für Syscall "mmap2" benötigten Parameter in den entsprechenden Registern
				mov		r1, #BCM2836_GPIO_MEMSIZE
				mov 	r2, #MMAP_PARAMETER_PROT_READ_WRITE
				mov		r3, #MMAP_PARAMETER_MAP_SHARED
				ldr		r4, =dev_mem_gpio_fd
				ldr		r4, [r4]
				ldr		r5, =BCM2836_GPIO_BASE
				lsr		r5, r5, #12
				mov 	r7, #SYSCALL_MMAP2
				swi		#0							//Ausführen von Softwareinterrupt
				ldr		r1, =mmap2_baseadress		//Speichern  der von "mmap2" in Register 0 zurückgegebenen Basisadress in Variable "mmap2_baseadress"
				str		r0, [r1]

				ldmfd	sp!,{r4-r11,lr}				//EABI
				bx 		lr
.endfunc

/*
Diese Funktion führt ein Memory unmap aus um den abgebildeten Speicher aus der Datei /dev/mem zu entfernen
Anschließend wird die Datei /dev/mem geschlossen.
*/
.func close
close:			mov		ip, sp						//EABI
				stmfd	sp!,{r4-r11,lr}
				mov 	fp, ip

				//memoryunmap
				ldr		r0, =mmap2_baseadress		//Übergeben der für den Syscall "munmap" benötigten Parameter in den entsprechenden Registern
				ldr		r0, [r0]
				mov 	r1, #BCM2836_GPIO_MEMSIZE
				mov 	r7, #91
				swi 	#0							//Ausführen von Softwareinterrupt -> Speicherabbildung aus Datei /dev/mem entfernen
				//Close devmem
				ldr		r0, =dev_mem_gpio_fd		//Übergeben der für den Syscall "close" benötigten Parameter in den entsprechenden Registern
				ldr		r0, [r0]
				mov 	r7, #6
				swi		#0							//Ausführen von Softwareinterrupt -> Schließen der Datei /dev/mem

				//return
				mov 	r0, #0						//Register r0 auf standard 0 setzen

				ldmfd	sp!,{r4-r11,lr}				//EABI
				bx 		lr
.endfunc



