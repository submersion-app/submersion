"""pytest wiring for the web smoke runner (smoke_test.py).

pytest reads hooks from a conftest or a plugin, never from a test module,
so the hook that tells the page fixture a test failed lives here.
"""

import pytest


@pytest.hookimpl(hookwrapper=True)
def pytest_runtest_makereport(item, call):
    """Records the call's result on the test, for the page fixture."""
    outcome = yield
    if call.when == "call":
        item.call_failed = outcome.get_result().failed
