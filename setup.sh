#!/bin/bash
set -e

PYTHON_BIN=$(command -v python3.11 || true)
if [ -z "$PYTHON_BIN" ]; then
  echo "❌ 沒找到 python3.11，請先安裝 (brew install python@3.11)"
  exit 1
fi

# 建立/啟用 venv
if [ ! -d "rag-venv" ]; then
  echo "📦 建立虛擬環境 rag-venv ..."
  $PYTHON_BIN -m venv rag-venv
fi
source rag-venv/bin/activate

# 安裝必要套件（含 FastAPI / Uvicorn / Streamlit）
pip install --upgrade pip >/dev/null
pip install unstructured pdfminer.six langchain langchain-community langchain-openai faiss-cpu tiktoken streamlit fastapi "uvicorn[standard]" pydantic >/dev/null

# 主程式：CLI + 互動 + Web + API
cat > rag_cli.py <<'PYCODE'
import os, sys, argparse, shutil, json, csv
from typing import List, Optional, Set
from unstructured.partition.pdf import partition_pdf
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain.schema import Document
from langchain_openai import OpenAIEmbeddings, ChatOpenAI
from langchain_community.vectorstores import FAISS
from langchain.prompts import ChatPromptTemplate

STORE_DIR = "storage"

# ---------- 共用：檢索 + 生成 ----------
def _load_vs_and_llm():
    embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
    vs = FAISS.load_local(STORE_DIR, embeddings, allow_dangerous_deserialization=True)
    llm = ChatOpenAI(model="gpt-4o-mini", temperature=0.2)
    return vs, llm

def _chunk_texts(docs: List[Document]) -> List[Document]:
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=800,
        chunk_overlap=120,
        separators=["\n\n", "\n", "。", " "],
    )
    return splitter.split_documents(docs)

def _answer_with_history(question: str, vs, llm, history: Optional[List[dict]] = None) -> (str, Set[str]):
    results = vs.similarity_search(question, k=5)
    context = "\n\n".join([r.page_content for r in results]) if results else "（無相關內容）"
    sources = {r.metadata.get("source", "unknown") for r in results}

    messages = [("system", "你是需求文件助理，僅依 context 與對話歷史回答。若找不到就說不知道。")]
    if history:
        for h in history:
            messages.append(("human", h.get("q","")))
            messages.append(("assistant", h.get("a","")))
    messages.append(("human", f"問題：{question}\n\nContext:\n{context}"))

    prompt = ChatPromptTemplate.from_messages(messages).format_messages()
    out = llm.invoke(prompt)
    return out.content, sources

# ---------- Ingest ----------
def ingest(pdf_files: List[str]):
    all_chunks = []
    for pdf_path in pdf_files:
        if not os.path.exists(pdf_path):
            print(f"❌ 找不到檔案 {pdf_path}")
            continue

        txt_path = os.path.splitext(pdf_path)[0] + ".txt"
        elements = partition_pdf(filename=pdf_path)
        with open(txt_path, "w", encoding="utf-8") as f:
            for el in elements:
                if getattr(el, "text", None):
                    f.write(el.text.strip() + "\n")
        print(f"[OK] 已轉換 {pdf_path} → {txt_path}")

        raw = open(txt_path, encoding="utf-8").read()
        docs = [Document(page_content=raw, metadata={"source": os.path.basename(pdf_path)})]
        chunks = _chunk_texts(docs)
        print(f"[OK] {pdf_path} 產生 {len(chunks)} 個 chunks")
        all_chunks.extend(chunks)

    if not all_chunks:
        print("⚠️ 沒有成功處理任何檔案")
        return

    embeddings = OpenAIEmbeddings(model="text-embedding-3-small")
    if os.path.exists(STORE_DIR):
        vs = FAISS.load_local(STORE_DIR, embeddings, allow_dangerous_deserialization=True)
        vs.add_documents(all_chunks)
        print(f"[OK] 已將 {len(all_chunks)} 個 chunks 加入現有向量庫")
    else:
        vs = FAISS.from_documents(all_chunks, embeddings)
        print(f"[OK] 建立新向量庫，包含 {len(all_chunks)} 個 chunks")
    vs.save_local(STORE_DIR)
    print(f"[OK] 向量庫儲存至 {STORE_DIR}/")

# ---------- Ask（單次） ----------
def ask(question: str):
    if not os.path.exists(STORE_DIR):
        print("❌ 尚未建立向量庫，請先執行 --ingest")
        sys.exit(1)
    vs, llm = _load_vs_and_llm()
    ans, sources = _answer_with_history(question, vs, llm, history=None)
    print("\n=== 問答結果 ===")
    print("Q:", question)
    print("A:", ans)
    print("📚 來源:", sources)

# ---------- Info / Clear / Export ----------
def info():
    if not os.path.exists(STORE_DIR):
        print("❌ 尚未建立向量庫"); return
    vs, _ = _load_vs_and_llm()
    try:
        count = vs.index.ntotal
    except:
        count = "未知"
    srcs = set()
    try:
        for d in vs.similarity_search("test", k=100):
            if "source" in d.metadata: srcs.add(d.metadata["source"])
    except: pass
    print("=== 向量庫資訊 ===")
    print(f"總 chunks: {count}")
    print(f"文件來源: {srcs if srcs else '無法解析'}")

def clear():
    if os.path.exists(STORE_DIR):
        shutil.rmtree(STORE_DIR); print(f"[OK] 已清空向量庫 {STORE_DIR}/")
    else:
        print("⚠️ 沒有找到向量庫，不需清空")

def export(fmt="json"):
    if not os.path.exists(STORE_DIR):
        print("❌ 尚未建立向量庫"); return
    vs, _ = _load_vs_and_llm()
    docs = vs.similarity_search("test", k=2000)
    rows = [{"text": d.page_content, "source": d.metadata.get("source","unknown")} for d in docs]
    if fmt == "json":
        with open("export.json","w",encoding="utf-8") as f: json.dump(rows,f,ensure_ascii=False,indent=2)
        print("[OK] 已輸出 export.json")
    elif fmt == "csv":
        import csv
        with open("export.csv","w",encoding="utf-8",newline="") as f:
            w = csv.DictWriter(f, fieldnames=["source","text"]); w.writeheader(); w.writerows(rows)
        print("[OK] 已輸出 export.csv")
    else:
        print("❌ 格式僅支援 json 或 csv")

# ---------- Interactive ----------
def interactive():
    if not os.path.exists(STORE_DIR):
        print("❌ 尚未建立向量庫，請先執行 --ingest"); return
    print("💬 進入互動模式（輸入 exit 離開，含多輪記憶）")
    vs, llm = _load_vs_and_llm()
    history: List[dict] = []
    while True:
        q = input("\n你: ")
        if q.lower() in ["exit","quit","q"]:
            print("👋 已離開互動模式"); break
        ans, sources = _answer_with_history(q, vs, llm, history=history)
        print(f"🤖 助理: {ans}\n📚 來源: {sources}")
        history.append({"q": q, "a": ans})

# ---------- Web (Streamlit) ----------
def web():
    import streamlit as st
    if not os.path.exists(STORE_DIR):
        st.error("尚未建立向量庫，請先執行 --ingest"); return
    st.title("📚 RAG Chat 助理")
    vs, llm = _load_vs_and_llm()
    if "history" not in st.session_state: st.session_state["history"]=[]
    q = st.text_input("輸入你的問題：")
    if st.button("送出") and q.strip():
        ans, sources = _answer_with_history(q, vs, llm, history=st.session_state["history"])
        st.session_state["history"].append({"q": q, "a": ans + f"\n📚 來源: {sources}"})
    for h in st.session_state["history"]:
        st.markdown(f"**你:** {h['q']}"); st.markdown(f"**助理:** {h['a']}")

# ---------- API (FastAPI) ----------
def api(host: str="127.0.0.1", port: int=8000):
    if not os.path.exists(STORE_DIR):
        print("❌ 尚未建立向量庫，請先執行 --ingest"); sys.exit(1)

    from fastapi import FastAPI
    from pydantic import BaseModel
    import uvicorn

    app = FastAPI(title="RAG API", version="1.0.0")
    vs, llm = _load_vs_and_llm()

    class QA(BaseModel):
        q: str
        a: str

    class AskBody(BaseModel):
        q: str
        history: Optional[List[QA]] = None

    @app.get("/health")
    def health():
        return {"ok": True}

    @app.post("/ask")
    def ask_route(body: AskBody):
        hist = [{"q": h.q, "a": h.a} for h in (body.history or [])]
        ans, sources = _answer_with_history(body.q, vs, llm, history=hist)
        return {"answer": ans, "sources": list(sources)}

    print(f"🚀 啟動 RAG API: http://{host}:{port}")
    uvicorn.run(app, host=host, port=port)

# ---------- Main ----------
def main():
    p = argparse.ArgumentParser(description="Mini RAG CLI / Web / API")
    p.add_argument("--ingest", nargs="+", help="輸入一個或多個 PDF 檔案，建立/更新向量庫")
    p.add_argument("--ask", type=str, help="輸入問題，查詢向量庫")
    p.add_argument("--info", action="store_true", help="顯示向量庫資訊")
    p.add_argument("--clear", action="store_true", help="清空向量庫")
    p.add_argument("--export", type=str, choices=["json","csv"], help="匯出 chunks")
    p.add_argument("--interactive", action="store_true", help="互動問答模式（多輪記憶）")
    p.add_argument("--web", action="store_true", help="啟動 Streamlit 介面")
    p.add_argument("--api", action="store_true", help="啟動 FastAPI 伺服器")
    p.add_argument("--host", type=str, default="127.0.0.1")
    p.add_argument("--port", type=int, default=8000)
    args = p.parse_args()

    if args.ingest: ingest(args.ingest); return
    if args.ask: ask(args.ask); return
    if args.info: info(); return
    if args.clear: clear(); return
    if args.export: export(args.export); return
    if args.interactive: interactive(); return
    if args.web:
        os.system("streamlit run rag_cli.py"); return
    if args.api: api(host=args.host, port=args.port); return
    p.print_help()

if __name__ == "__main__":
    if not os.getenv("OPENAI_API_KEY"):
        print("⚠️ 尚未設定 OPENAI_API_KEY")
    main()
PYCODE

# 轉交所有 CLI 參數（含 --api）
python rag_cli.py "$@"
