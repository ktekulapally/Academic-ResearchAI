import os
from fastmcp import FastMCP
from .db import SessionLocal
from .models import Subject, QuestionCluster
from .llm import chat_json
from .documents import extract_pdf_text

# Create FastMCP server instance
mcp = FastMCP("Academic Research AI MCP Server")

@mcp.tool()
def search_exam_papers(subject_name: str, standard_name: str) -> str:
    """
    Generate target exam queries and search for candidate links online.
    Useful for discovering where previous papers can be downloaded.
    """
    from .search import search_searxng
    query = f"{standard_name} {subject_name} board exam question papers PDF"
    try:
        results = search_searxng(query, limit=5)
        if not results:
            return "No immediate papers found online."
        links = []
        for r in results:
            links.append(f"- [{r['title']}]({r['url']})")
        return "\n".join(links)
    except Exception as e:
        return f"Error executing search: {e}"

@mcp.tool()
def extract_questions_from_pdf(pdf_path: str) -> str:
    """
    Run layout extraction and OCR on a local PDF file path to extract all exam questions.
    Returns structured text extracted from the file.
    """
    if not os.path.exists(pdf_path):
        return f"Error: File not found at path {pdf_path}"
    try:
        text = extract_pdf_text(pdf_path)
        return text[:15000]  # Return first 15k characters of raw exam text
    except Exception as e:
        return f"Error parsing PDF: {e}"

@mcp.tool()
def get_top_recurring_questions(subject_id: int, limit: int = 10) -> str:
    """
    Get the top recurring exam questions, frequency counts, years appeared, and standard answers
    from the database for a given subject.
    """
    db = SessionLocal()
    try:
        clusters = db.query(QuestionCluster).filter(QuestionCluster.subject_id == subject_id).order_by(
            QuestionCluster.frequency_count.desc()
        ).limit(limit).all()
        if not clusters:
            return "No question clusters analyzed yet for this subject."
        output = []
        for idx, c in enumerate(clusters):
            output.append(
                f"### {idx+1}. {c.canonical_text}\n"
                f"- **Appeared**: {c.frequency_count} times\n"
                f"- **Years**: {c.years_appeared}\n"
                f"- **Solution**: {c.solution_markdown or 'Solution pending analysis'}\n"
            )
        return "\n".join(output)
    except Exception as e:
        return f"Error querying database: {e}"
    finally:
        db.close()

@mcp.tool()
def ask_tutor_follow_up(cluster_id: int, query: str) -> str:
    """
    Ask the academic tutor a follow-up clarification question regarding a specific exam question solution.
    """
    db = SessionLocal()
    try:
        cluster = db.get(QuestionCluster, cluster_id)
        if not cluster:
            return "Error: Question cluster not found."
            
        sol_prompt = (
            f"You are an academic tutor helping a student understand this exam question:\n"
            f"QUESTION: {cluster.canonical_text}\n"
            f"STANDARD SOLUTION:\n{cluster.solution_markdown}\n\n"
            f"The student is asking this follow-up question:\n"
            f"STUDENT QUERY: {query}\n\n"
            f"Provide a clear, detailed, and helpful response. Use LaTeX notation for formulas.\n"
            f"Return JSON with key 'response' containing your markdown text answer."
        )
        res_data = chat_json(sol_prompt)
        return res_data.get("response", "No response synthesized.")
    except Exception as e:
        return f"Error calling LLM: {e}"
    finally:
        db.close()

if __name__ == "__main__":
    mcp.run()
