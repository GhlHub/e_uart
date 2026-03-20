# Verification

## XSIM flow

The repository includes two self-checking XSIM targets:

- `int_holdoff_tb`
- `int_holdoff_axi_tb`

Run them with:

```bash
tb/run_xsim.sh all
```

Or individually:

```bash
tb/run_xsim.sh int_holdoff_tb
tb/run_xsim.sh int_holdoff_axi_tb
```

Build products are written under `out/xsim/<top>/`.

Each run:

- compiles with `xvlog`
- elaborates with `xelab`
- runs with `xsim`
- logs all waves into `<top>.wdb`

The testbenches also print simulation time rounded to the nearest ns.
