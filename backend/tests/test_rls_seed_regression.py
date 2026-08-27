def test_isolation_test_fails_fast_when_seed_fails(monkeypatch):
    """
    Regression guard: if _seed_test_record() raises, the isolation test
    must fail loudly (AssertionError), not pass silently.
    """
    import backend.tests.test_rls as rls_module
    import pytest
    from unittest.mock import MagicMock

    def always_fail(*args, **kwargs):
        raise Exception("simulated seed failure")

    monkeypatch.setattr(rls_module, "_seed_test_record", always_fail)

    fake_client_a = MagicMock()
    fake_client_b = MagicMock()
    fake_authenticated_clients = (fake_client_a, fake_client_b, "fake-user-a-id", "fake-user-b-id")

    with pytest.raises(AssertionError, match="Setup failed"):
        rls_module.test_cross_student_data_isolation(fake_authenticated_clients, "user_topic_weights")