import os

from groq import Groq

GROQ_MODEL = "llama-3.3-70b-versatile"

_groq_client = None

def get_groq_client():
    global _groq_client
    if _groq_client is None:
        _groq_client = Groq(api_key=os.getenv("GROQ_API_KEY"))
    return _groq_client
