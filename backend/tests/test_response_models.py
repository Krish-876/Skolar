"""
Tests that the batch generation response models carry 'requested' and
'generated' counts, so a caller can see a shortfall (e.g. main.py returning
200 with fewer questions than asked for) instead of it being silent.
"""

import sys
from pathlib import Path

import pytest
from pydantic import ValidationError

BACKEND_DIR = Path(__file__).resolve().parent.parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from pyq.rag.main import (  # noqa: E402
    GenerateBatchResponse,
    GenerateOpenBatchResponse,
    McqQuestion,
    OpenQuestion,
)


def test_generate_batch_response_carries_requested_and_generated():
    response = GenerateBatchResponse(
        questions=[
            McqQuestion(
                question="Q1", options=["A", "B", "C", "D"], correct_index=0,
                subject="OS", marks=2,
            ),
        ],
        subject="OS",
        requested=10,
        generated=1,
    )

    assert response.requested == 10
    assert response.generated == 1
    assert response.generated < response.requested  # shortfall is visible on the model


def test_generate_open_batch_response_carries_requested_and_generated():
    response = GenerateOpenBatchResponse(
        questions=[
            OpenQuestion(question="Q1", subject="OS", marks=5, model_answer="A1"),
            OpenQuestion(question="Q2", subject="OS", marks=5, model_answer="A2"),
            OpenQuestion(question="Q3", subject="OS", marks=5, model_answer="A3"),
        ],
        subject="OS",
        requested=5,
        generated=3,
    )

    assert response.requested == 5
    assert response.generated == 3
    assert response.generated < response.requested


def test_generate_batch_response_requested_generated_are_required_fields():
    with pytest.raises(ValidationError):
        GenerateBatchResponse(questions=[], subject="OS")  # missing requested/generated


def test_generate_batch_response_full_count_shows_no_shortfall():
    response = GenerateBatchResponse(
        questions=[
            McqQuestion(question=f"Q{i}", options=["A", "B", "C", "D"], correct_index=0, subject="OS", marks=2)
            for i in range(5)
        ],
        subject="OS",
        requested=5,
        generated=5,
    )

    assert response.requested == response.generated
