import sys, torch, numpy as np
sd = torch.load(sys.argv[1], map_location="cpu")
order = ["enc.weight", "norm.weight", "norm.bias", "inp.weight", "inp.bias",
         "gru.weight_ih_l0", "gru.weight_hh_l0", "gru.bias_ih_l0", "gru.bias_hh_l0",
         "gru.weight_ih_l1", "gru.weight_hh_l1", "gru.bias_ih_l1", "gru.bias_hh_l1",
         "mask.weight", "mask.bias", "gain.weight", "gain.bias", "dec.weight"]
with open(sys.argv[2], "wb") as f:
    f.write(np.array([sd["enc.weight"].shape[0], sd["gru.weight_hh_l0"].shape[1], sd["enc.weight"].shape[2], 1 if len(sys.argv) > 3 else 0], np.int32).tobytes())
    for k in order: f.write(sd[k].float().contiguous().numpy().tobytes())
    if len(sys.argv) > 3:
        import json
        f.write(np.array(json.load(open(sys.argv[3]))["tone_db"], np.float32).tobytes())
