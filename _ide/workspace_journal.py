# 2026-06-17T05:19:29.981591719
import vitis

client = vitis.create_client()
client.set_workspace(path="riscv-core")

vitis.dispose()

