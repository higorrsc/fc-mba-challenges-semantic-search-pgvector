from .search import search_prompt


def main() -> None:
    """Main entrypoint"""

    try:
        chain = search_prompt()
    except Exception as e:
        print(f"❌ Erro ao inicializar o chat: {e}")
        return

    while True:
        question = input("Pergunta (ou 'sair' para sair): ")

        if question.lower() == "sair":
            break

        answer = chain(question)
        print(f"Resposta: {answer}\n\n")


if __name__ == "__main__":
    main()
