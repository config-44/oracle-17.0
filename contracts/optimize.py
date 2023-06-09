# -*- coding: utf-8 -*-
from __future__ import annotations
import re
from typing import Callable
import argparse


#
#   |\      _,,,---,,_
#   /,`.-'`'    -.  ;-;;,_
#  |,4-  ) )-,_..;\ (  `'-'
# '---''(_/--'  `-'\_)
#
# The sleeping cat on the mat
# Looks so cozy and fat (｡◕‿◕｡)
#


def read_file(filename: str) -> str:
    with open(filename, "r") as f:
        return f.read()


class Remover:
    linesd: list[str]
    to_rem: list[str]
    result: list[str]
    in_ctx: bool
    crline: str

    def __init__(self, input: str, to_rem: list[str]) -> None:
        self.linesd = input.split("\n")
        self.to_rem = to_rem

        self.result = []
        self.in_ctx = False
        self.crline = ""

    def __in_crline(self, to_remove: list[str]) -> bool:
        for arg in to_remove:
            if arg in self.crline:
                return True
        return False

    def __next_line(self, line: str) -> None:
        if self.__in_crline(self.to_rem):
            self.in_ctx = True
            return

        if self.in_ctx and self.__in_crline([".macro", ".internal-alias"]):
            self.in_ctx = False

        if not self.in_ctx:
            self.result.append(line)

    def process(self) -> str:
        for _, line in enumerate(self.linesd):
            self.crline = line
            self.__next_line(line)

        return "\n".join(self.result)


class Replacer:
    input: str
    to_replace: list[tuple[str, str]]

    def __init__(self, input: str, to_replace: list[tuple[str, str]]) -> None:
        self.input = input
        self.to_replace = to_replace

    def process(self) -> str:
        for r in self.to_replace:
            self.input = self.input.replace(r[0], r[1])

        return self.input


class Kitten:
    code: list[str]
    skip_next: bool

    HandlerType = Callable[[int, str, list[str]], tuple[int, bool]]

    def __init__(self, input: str) -> None:
        self.code = input.split("\n")
        self.skip_next = False

    def __iterate(self, handler: HandlerType) -> list[str]:
        new_code: list[str] = []
        skip_cnt = 0

        for i, instr in enumerate(self.code):
            if skip_cnt > 0:
                skip_cnt -= 1
                continue

            if "}" not in instr:  # can be extended with more patterns
                (skip_cnt_add, skip_curr) = handler(i, instr, new_code)
                skip_cnt += skip_cnt_add

                if skip_curr:
                    continue

            if ".loc" not in instr:
                new_code.append(instr)

        return new_code

    def inline_asm_functions(self) -> str:
        def __in(i: int, instr: str, new_code: list[str]) -> tuple[int, bool]:
            if ("PRINTSTR" in instr):
                slice = instr.strip().split(" ")[1][1:].strip()
                arg_str = bytes.fromhex(slice).decode('utf-8')

                in_l:   str
                out_l:  str
                op:     str

                if ":" in arg_str:
                    in_l, out_l, op, *_ = arg_str.split(':')
                else:
                    in_l, out_l, op = "0", "0", arg_str[1:]

                for _ in range(int(out_l)):
                    new_code.pop()

                new_code.extend([op])
                return (int(in_l), True)

            return (0, False)

        return "\n".join(self.__iterate(__in))

    def ctr_and_pubkey_removal_load(self) -> str:
        def __in(i: int, instr: str, new_code: list[str]) -> tuple[int, bool]:
            if (".macro __load_data" in instr)                    \
                    and i + 5 < len(self.code)                  \
                    and "PUSHROOT" in self.code[i+1]            \
                    and "CTOS" in self.code[i+2]                \
                    and "LDU 256 ; pubkey c4" in self.code[i+3] \
                    and "LDU 1 ; ctor flag" in self.code[i+4]   \
                    and "NIP" in self.code[i+5]:

                k = 6
                not_found = True
                btwn_ops: list[str] = []

                while not_found:
                    if self.code[i + k] == "SETGLOB 2":
                        not_found = False
                        continue

                    btwn_ops.append(self.code[i + k])
                    k += 1

                to_extend = [
                    ".macro __load_data",
                    "PUSHROOT",
                    "CTOS"
                ]

                to_extend += btwn_ops
                new_code.extend(to_extend)
                return (5 + len(btwn_ops) + 1, True)

            return (0, False)

        return "\n".join(self.__iterate(__in))

    def ctr_and_pubkey_removal_save(self) -> str:
        def __in(i: int, instr: str, new_code: list[str]) -> tuple[int, bool]:
            if (".macro __save_data" in instr):
                k = 1
                not_found = True
                btwn_ops: list[str] = []

                while not_found:
                    if i + k >= len(self.code):
                        return (0, False)

                    if self.code[i + k] == "STU 256" and \
                            self.code[i + k + 1] == "STONE":

                        not_found = False
                        continue

                    btwn_ops.append(self.code[i + k])
                    k += 1

                to_extend = [".macro __save_data"]
                to_extend += btwn_ops[:-2] + ["NEWC"]

                new_code.extend(to_extend)
                return (len(btwn_ops) + 2, True)

            return (0, False)

        return "\n".join(self.__iterate(__in))

    def overflow_checks_removal(self) -> str:
        def __in(i: int, instr: str, new_code: list[str]) -> tuple[int, bool]:
            if ("UFITS" in instr or "FITS" in instr):
                return (0, True)

            return (0, False)

        return "\n".join(self.__iterate(__in))


    def beautify_macro_name(self) -> str:
        def __in(i: int, instr: str, new_code: list[str]) -> tuple[int, bool]:
            if "_internal_macro" in instr and instr.startswith(".macro"):
                n = re.sub(r"(_[a-f0-9]+)*_internal_macro", "", instr)
                new_code.extend([n])
                return (0, True)

            if "_internal_macro" in instr and instr.strip().endswith("$"):
                n = re.sub(r"(_[a-f0-9]+)*_internal_macro\$", "$", instr)
                new_code.extend([n])
                return (0, True)

            return (0, False)

        return "\n".join(self.__iterate(__in))

    def fix_ldslicex_512_in_asm(self) -> str:
        def __in(i: int, instr: str, new_code: list[str]) -> tuple[int, bool]:
            if "LDSLICE 512" in instr:
                new_code.extend(["PUSHPOW2 9", "LDSLICEX"])
                return (0, True)

            return (0, False)

        return "\n".join(self.__iterate(__in))


def recognize_recv_x(code: str) -> str:
    if ('recv_internal' not in code) and ('recv_external' not in code):
        return code

    TO_REMOVE = [
        ".internal-alias :main_external, -1",
        ".internal-alias :main_internal, 0",
        ".macro __load_data",
        ".macro __save_data",
        ".macro c4_to_c7_with_init_storage",
        ".macro public_function_selector",
        ".macro constructor",
        "upd_only_time_in_c4"
    ]

    TO_REPLACE = [
        (
            ".macro recv_internal",
            # =>
            ".internal-alias :main_internal, 0\n" + \
            ".internal :main_internal"
        ),

        (
            ".macro recv_external",
            # =>
            ".internal-alias :main_external, -1\n" + \
            ".internal :main_external"
        ),

        (".macro c4_to_c7", ".macro __load_data"),
        (".macro c7_to_c4", ".macro __save_data")
    ]

    _0: str = Remover(code, TO_REMOVE).process()
    _1: str = Replacer(_0, TO_REPLACE).process()

    return _1


def replace_opcodes(code: str) -> str:
    TO_REPLACE = [
        ("SLICE ", "PUSHSLICE "),
        ("PUSHPUSHSLICE ", "PUSHSLICE "),
        (".blob ZERO32", "\t.blob x00000000"),
        ("THROW404", "PUSHPOW2DEC 16\nTHROWANY"),
    ]

    _0: str = Replacer(code, TO_REPLACE).process()
    return _0


def main():
    parser = argparse.ArgumentParser(
        prog='optimize.py',
        description='solidity asm code optimizer',
    )

    parser.add_argument('filename')
    args = parser.parse_args()

    code = read_file(args.filename)

    code: str = Kitten(code).overflow_checks_removal()
    code: str = Kitten(code).fix_ldslicex_512_in_asm()
    code: str = Kitten(code).beautify_macro_name()
    code: str = recognize_recv_x(code)
    code: str = Kitten(code).inline_asm_functions()
    code: str = Kitten(code).ctr_and_pubkey_removal_load()
    code: str = Kitten(code).ctr_and_pubkey_removal_save()
    code: str = replace_opcodes(code)

    with open(args.filename, "w") as f:
        f.write(code)


if __name__ == "__main__":
    main()
