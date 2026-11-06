# Tandoor's AI calls send no reasoning_effort, and with thinking off (the Sparks' default)
# GLM-5.3 Flash returns broken recipe JSON. Adds reasoning_effort to calls aimed at the Sparks.
# Patches litellm when it's first imported, because importing it up front adds ~6 s to every
# manage.py run in boot.sh.
import importlib.abc
import importlib.util
import sys

SPARK_API_BASE = "http://192.168.1.106:8888/v1"


def _patch(litellm):
    completion = litellm.completion

    def completion_with_reasoning(*args, **kwargs):
        if kwargs.get("api_base") == SPARK_API_BASE:
            kwargs.setdefault("reasoning_effort", "low")
        return completion(*args, **kwargs)

    litellm.completion = completion_with_reasoning


class _PatchOnImport(importlib.abc.MetaPathFinder):
    def find_spec(self, name, path, target=None):
        if name != "litellm":
            return None
        sys.meta_path.remove(self)
        spec = importlib.util.find_spec(name)
        exec_module = spec.loader.exec_module

        def exec_and_patch(module):
            exec_module(module)
            _patch(module)

        spec.loader.exec_module = exec_and_patch
        return spec


sys.meta_path.insert(0, _PatchOnImport())
