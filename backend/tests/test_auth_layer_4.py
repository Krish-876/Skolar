from types import SimpleNamespace

import pytest
from fastapi import HTTPException

from app.dependencies import require_student_or_admin
from nova.api.deps import require_same_user


def test_student_or_admin_requires_trusted_role_metadata():
    request = SimpleNamespace(
        state=SimpleNamespace(
            custom_roles=["student"],
            custom_roles_trusted=False,
            user_id="student-1",
        )
    )

    with pytest.raises(HTTPException) as error:
        require_student_or_admin(request)

    assert error.value.status_code == 403
    assert error.value.detail == "Insufficient permissions."


@pytest.mark.parametrize("role", ["student", "admin"])
def test_student_and_admin_roles_are_allowed(role):
    request = SimpleNamespace(
        state=SimpleNamespace(
            custom_roles=[role],
            custom_roles_trusted=True,
            user_id="user-1",
        )
    )

    assert require_student_or_admin(request) == "user-1"


def test_unknown_application_role_is_denied():
    request = SimpleNamespace(
        state=SimpleNamespace(
            custom_roles=["teacher"],
            custom_roles_trusted=True,
            user_id="user-1",
        )
    )

    with pytest.raises(HTTPException) as error:
        require_student_or_admin(request)

    assert error.value.status_code == 403


def test_nova_object_scope_rejects_another_users_resource():
    with pytest.raises(HTTPException) as error:
        require_same_user("student-b", authenticated_user_id="student-a")

    assert error.value.status_code == 403
    assert error.value.detail == "Cannot access another user's data."


def test_nova_object_scope_allows_the_authenticated_owner():
    assert require_same_user("student-a", authenticated_user_id="student-a") == "student-a"
