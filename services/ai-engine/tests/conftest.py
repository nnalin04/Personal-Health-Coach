import pytest
import app.main as main_module


@pytest.fixture(autouse=True)
def reset_rate_limit():
    """Clear the in-memory rate-limit log before every test so tests don't
    bleed request counts into each other."""
    main_module._request_log.clear()
    yield
    main_module._request_log.clear()
