from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain.schema import Document
# 假設已經從 PDF 擷取文字
raw_text = open("需求說明書.txt", encoding="utf-8").read()
# 建立 Document (附帶 metadata)
doc = Document(page_content=raw_text, metadata={"source": "需求說明書.pdf"})
# 分割器設定
splitter = RecursiveCharacterTextSplitter(
    chunk_size=800,    # 每段約 800 tokens
    chunk_overlap=120, # 重疊區 120 tokens
    separators=["\n\n", "\n", "。", " "]
)
# 切分文件
chunks = splitter.split_documents([doc])
print(f"總共產生 {len(chunks)} 個文本區塊")
