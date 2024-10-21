OUTPUT_FORMAT("binary")

SECTIONS {
    .text.start : {
        prelude.o(.text)
    }

    .text : ALIGN(0x10) {
        *(.text)
    }

    .data : ALIGN(0x10) {
        *(.data)
    }
}
