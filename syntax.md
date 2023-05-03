# Instructions
Instructions can be ran with 2 primary arguments: a target register and a value.
Valid syntax for instructions are as follows:
```py
instruction register: value;
# for example
add x: 12;

DEFINE TEST: 123;
set y: TEST;

instruction register;
# for example
LABEL MAIN;

instruction: value;
# for example
SOME_MACRO: 25;

instruction;
# for example
break;
```
# Macros
Macros can be written the same way as an instruction, with the following syntatical extensions:
```py
# more than 2 arguments
MACRONAME(arbitrary_arg1, arbitrary_arg2, arbitrary_arg3);

# include scope as argument 2
DEFINE NEW_MACRO_NAME: {
    
}
```
# Arguments
## Values
Values can either be a valid number (will wrap from 0-65535), a known register (`a` - address, `m` - memory, `x` or `y` - general purpose), or a defined name.
## Names
A name can be any input that matches the character set `[A-Z_]`, and is used within macros.
## Registers
Registers can be one of the following:
- `x` - A general purpose register, can store any number between 0 and 65535
- `y` - A general purpose register, can store any number between 0 and 65535
- `a` - A register that holds an address, controls where `m` points to. Can store any number between 0 and 65535
- `m` - A value in memory based on the address `a`. Can store any number between 0 and 65535
## Arbitrary Arguments
An arbitrary argument is any value that does not contain a comma or a close parenthesees ( `,` or `)` ). Arbitrary arguments are enclosed in parenthesees and can be used within user-defined macros.
## Block
A block input is a set of instructions enclosed in braces ( `{}` ) to be passed as input.
# Built-in Macros
## `DEFINE [+/-][g]CONSTANT: VALUE;`
This defines a constant under the specified value. The name can later be used in place of a value, similar to how a number constant would be used in most other programming languages. Defines are confined within the scope unless you prefix the name with `g` (this does NOT change the constant name.) Prefixing the constant name with a `+` or a `-` will instead modify an existing constant. The `DEFINE` must occur before any usage of the constant.
## `DEFINE CONSTANT: {BLOCK};`
This defines a macro that resolves to the specified block input. This block input may contain anywhere within it a `$n` replacer. It will be replaced by the `n`th argument passed to the macro. The `DEFINE` must occur before any usage of the constant.
## `LABEL CONSTANT;`
This defines a constant with the value matching the position in the code the label is at. The `LABEL` can occur anywhere in a file, so long as the parser is able to locate a label declaration beforehand. 
# Proposals
## Constant indexing (`CONSTANT<OFFSET>`)
Adds notation for inserting a value adjacent to the provided constant. For example: `SOMETHING<3>` or `SCREEN<64>`