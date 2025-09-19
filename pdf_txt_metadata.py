from unstructured.partition.pdf import partition_pdf
from langchain_text_splitters import RecursiveCharacterTextSplitter
from langchain.schema import Document

# Step 1: PDF → TXT
pdf_path = "需求說明書.pdf"
txt_path = "需求說明書.txt"

elements = partition_pdf(filename=pdf_path)

with open(txt_path, "w", encoding="utf-8") as f:
    for el in elements:
        if el.text:  # 避免 None
            f.write(el.text + "\n")

print(f"[INFO] PDF 已轉換並儲存至 {txt_path}")

# Step 2: 讀取文字
raw_text = open(txt_path, encoding="utf-8").read()

# 建立 Document，附帶 metadata
doc = Document(page_content=raw_text, metadata={"source": pdf_path})

# Step 3: Chunking
splitter = RecursiveCharacterTextSplitter(
    chunk_size=800,    # 每段約 800 tokens
    chunk_overlap=120, # 重疊區 120 tokens
    separators=["\n\n", "\n", "。", " "]
)

chunks = splitter.split_documents([doc])
print(f"[INFO] 總共產生 {len(chunks)} 個文本區塊")

