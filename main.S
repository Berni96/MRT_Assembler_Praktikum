/*
 * main.S
 *
 *  Created on: 08.12.2019
 *      Author: mrt
 */

//GPIO Funktionen
.equ	BCM2836_GPIO_FUN_INPUT,		0b000			//Input
.equ	BCM2836_GPIO_FUN_OUTPUT,	0b001			//Output
.equ	BCM2836_GPIO_FUN_ALT0,		0b100			//Akternativfunktionen
.equ	BCM2836_GPIO_FUN_ALT1,		0b101			//  .
.equ	BCM2836_GPIO_FUN_ALT2,		0b110			//  .
.equ	BCM2836_GPIO_FUN_ALT3,		0b111			//  .
.equ	BCM2836_GPIO_FUN_ALT4,		0b011			//  .
.equ	BCM2836_GPIO_FUN_ALT5,		0b010			//  .

.equ 	GPIO_GREEN,					17
.equ	GPIO_YELLOW,				27
.equ	GPIO_RED,					22
.equ	GPIO_BUTTON,				23

.data
.balign 4
round:	.word						0
.text
.balign 4

.global main

.func main
main:		mov 	ip, sp							//EABI
			stmfd	sp!,{r4-r11,lr}
			mov 	fp, ip

			bl		open							//Öffnen von devmem und memorymapping mit Funktion "open" ausführen

			//Alle GPIOS auf die gewünschte Funktion einstellen
			mov		r0, #GPIO_BUTTON				//GPIOnummer des Tasters an gp_fsel übergeben
			mov		r1, #BCM2836_GPIO_FUN_INPUT		//Inputmuster an gpio_fsel übergeben
			bl		gpio_fsel						//Funktion mit "gpio_fsel" einstellen

			mov		r0, #GPIO_GREEN					//GPIOnummer der roten LED an gp_fsel übergeben
			mov		r1, #BCM2836_GPIO_FUN_OUTPUT	//Outputmuster an gpio_fsel übergeben
			bl		gpio_fsel						//Funktion mit "gpio_fsel" einstellen

			mov		r0, #GPIO_YELLOW				//GPIOnummer der roten LED an gp_fsel übergeben
			mov		r1, #BCM2836_GPIO_FUN_OUTPUT	//Outputmuster an gpio_fsel übergeben
			bl		gpio_fsel						//Funktion mit "gpio_fsel" einstellen

			mov		r0, #GPIO_RED					//GPIOnummer der roten LED an gp_fsel übergeben
			mov		r1, #BCM2836_GPIO_FUN_OUTPUT	//Outputmuster an gpio_fsel übergeben
			bl		gpio_fsel						//Funktion mit "gpio_fsel" einstellen

			mov		r0, #GPIO_BUTTON				//Den Taster so einstellen, dass er auf steigende Flanken reagiert
 			bl		r_flank_enable


wait:		mov		r0, #GPIO_BUTTON
			bl 		read_button

			cmp		r0, #0
			beq		wait

			ldr		r0, =round
			ldr		r0, [r0]
			cmp		r0, #1
			beq		round_2



round1:		mov 	r0, #GPIO_BUTTON
			bl		button_clr



			mov 	r0, #GPIO_RED
			bl		gpio_set

			mov		r0, #1
			bl		sleep

			mov 	r0, #GPIO_RED
			bl		gpio_clr


			mov		r0, #GPIO_YELLOW
			bl		gpio_set

			mov		r0, #1
			bl  	sleep

			mov 	r0, #GPIO_YELLOW
			bl		gpio_clr


			mov		r0, #GPIO_GREEN
			bl		gpio_set

			mov		r0, #1
			bl  	sleep

			mov 	r0, #GPIO_GREEN
			bl		gpio_clr

			ldr		r0, =round
			ldr		r1, [r0]
			add		r1, r1, #1
			str		r1, [r0]

			b		wait

round_2:	mov 	r0, #GPIO_BUTTON
			bl		button_clr

			mov		r0, #GPIO_YELLOW
			bl		gpio_set

			mov		r0, #2
			bl  	sleep

			mov 	r0, #GPIO_YELLOW
			bl		gpio_clr

			mov 	r0, #GPIO_RED
			bl		gpio_set

			mov		r0, #2
			bl		sleep

			mov 	r0, #GPIO_RED
			bl		gpio_clr

			mov		r0, #GPIO_GREEN
			bl		gpio_set

			mov		r0, #2
			bl sleep

			mov 	r0, #GPIO_GREEN
			bl 		gpio_clr

			bl		close							//nach zweitem Durchlauf memory unmap ausführen und Datei dev/mem schließen

			ldmfd	sp!,{r4-r11,lr}					//EABI
			bx		lr
.endfunc
