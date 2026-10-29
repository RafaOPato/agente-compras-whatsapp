"""Embute os prompts (prompts/*.md) no nó "Compor Prompt" do fluxo v2.

    python n8n/embute_prompts.py          # reescreve v2-agente/01-agente-compras.json
    python n8n/embute_prompts.py --check  # só confere; sai com 1 se estiver desatualizado

O n8n não lê arquivo dentro do nó Code, então o texto vai dentro do JSON do fluxo.
Prompt do engenheiro = agente-compras.md + regras-de-equalizacao.md.
"""
import json
import pathlib
import re
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
FLUXO = RAIZ / "n8n" / "v2-agente" / "01-agente-compras.json"
LER = lambda nome: (RAIZ / "prompts" / nome).read_text(encoding="utf-8").strip() + "\n"

PROMPTS = {
    "PROMPT_ENGENHEIRO": LER("agente-compras.md") + "\n" + LER("regras-de-equalizacao.md"),
    "PROMPT_FORNECEDOR": LER("agente-compras-fornecedor.md"),
}


def main(checar):
    fluxo = json.loads(FLUXO.read_text(encoding="utf-8"))
    no = next(n for n in fluxo["nodes"] if n["name"] == "Compor Prompt")
    codigo = no["parameters"]["jsCode"]
    for nome, texto in PROMPTS.items():
        linha = f"const {nome} = {json.dumps(texto, ensure_ascii=False)};"
        codigo, n = re.subn(rf"^const {nome} = .*;$", lambda _: linha, codigo, count=1, flags=re.M)
        if n != 1:
            sys.exit(f"não achei 'const {nome} = ...;' no nó Compor Prompt")
    if codigo == no["parameters"]["jsCode"]:
        print("prompts já estão em dia no fluxo")
        return 0
    if checar:
        print("DESATUALIZADO: rode python n8n/embute_prompts.py")
        return 1
    no["parameters"]["jsCode"] = codigo
    FLUXO.write_text(json.dumps(fluxo, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("prompts embutidos em", FLUXO.relative_to(RAIZ))
    return 0


if __name__ == "__main__":
    sys.exit(main("--check" in sys.argv))
