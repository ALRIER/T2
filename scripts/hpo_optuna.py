#!/usr/bin/env python3
"""Experimental Optuna tuner for frozen Monte Carlo scenario folds.

Does not modify the existing discovery or validation pipeline.
Prerequisites: optuna, Rscript, jsonlite and canonical Monte Carlo archives.
"""
import argparse
import json
import pathlib
import subprocess

import optuna


def suggest(trial, engine):
    cfg = {
        "population": trial.suggest_categorical("population", [50, 100, 150, 200]),
        "generations": trial.suggest_int("generations", 40, 100, step=20),
        "patience": trial.suggest_int("patience", 6, 16, step=2),
        "patience_extension": trial.suggest_int("patience_extension", 6, 18, step=3),
        "warmup_fraction": trial.suggest_categorical("warmup_fraction", [0.25, 0.4, 0.55]),
        "stop_window": trial.suggest_categorical("stop_window", [6, 10, 14]),
        "improvement": trial.suggest_float("improvement", 1e-4, 1e-2, log=True),
    }
    if engine in ("ga", "nsga2"):
        cfg["mutation_rate"] = trial.suggest_float("mutation_rate", 0.04, 0.4)
        cfg["crossover_probability"] = trial.suggest_float("crossover_probability", 0.5, 0.98)
    elif engine == "de":
        cfg["F"] = trial.suggest_float("F", 0.25, 1.2)
        cfg["CR"] = trial.suggest_float("CR", 0.35, 0.98)
    elif engine == "dirichlet":
        cfg["alpha"] = trial.suggest_float("alpha", 0.05, 10, log=True)
        cfg["n_draws"] = trial.suggest_categorical("n_draws", [2000, 6000, 12000])
    return cfg


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--engine", choices=["ga", "nsga2", "de", "dirichlet"], required=True)
    p.add_argument("--family", choices=["normal", "lognormal", "weibull", "invgauss", "exgaussian", "exwald"], required=True)
    p.add_argument("--trials", type=int, default=20)
    p.add_argument("--folds", type=int, default=3)
    p.add_argument("--seeds", default=",".join(str(i) for i in range(10)))
    p.add_argument("--output", default="artifacts/hpo_v1")
    args = p.parse_args()
    if args.folds != 3:
        p.error("HPO v1 currently implements three grouped contamination mechanism folds.")
    seeds = [int(s) for s in args.seeds.split(",")]
    if not seeds or len(set(seeds)) != len(seeds) or not all(0 <= s <= 9 for s in seeds):
        p.error("--seeds must be distinct discovery indices 0..9")
    root = pathlib.Path(args.output) / args.family / args.engine
    root.mkdir(parents=True, exist_ok=True)
    storage = "sqlite:///" + str((root / "optuna.sqlite3").resolve())
    study = optuna.create_study(
        study_name=f"hpo_v1_{args.family}_{args.engine}",
        storage=storage, direction="minimize", load_if_exists=True,
        sampler=optuna.samplers.TPESampler(seed=314159),
    )

    def objective(trial):
        params = suggest(trial, args.engine)
        work = root / f"trial_{trial.number:05d}"
        work.mkdir(parents=True, exist_ok=True)
        params_file = work / "params.json"
        params_file.write_text(json.dumps(params, indent=2), encoding="utf-8")
        rows = []
        for fold in range(1, 4):
            for seed in seeds:
                cmd = ["bash", "scripts/run_r_in_container.sh", "Rscript", "scripts/hpo_evaluate_trial.R",
                       args.engine, args.family, str(params_file), str(fold), str(seed)]
                proc = subprocess.run(cmd, text=True, capture_output=True, check=False)
                (work / f"fold{fold}_seed{seed}.stdout").write_text(proc.stdout, encoding="utf-8")
                (work / f"fold{fold}_seed{seed}.stderr").write_text(proc.stderr, encoding="utf-8")
                if proc.returncode:
                    raise RuntimeError(f"R evaluator error on fold={fold}, seed={seed}: {proc.stderr[-1200:]}")
                rows.append(json.loads(proc.stdout.strip().splitlines()[-1]))
        (work / "fold_metrics.json").write_text(json.dumps(rows, indent=2), encoding="utf-8")
        # Pilot scalar objective. A final, preregistered cross-fold metric
        # and computational accounting are required before confirmatory use.
        mse = sum(r["mse_ratio"] for r in rows) / len(rows)
        q95 = sum(r["q95_ratio"] for r in rows) / len(rows)
        trial.set_user_attr("fold_mse", mse)
        trial.set_user_attr("fold_q95", q95)
        generation_fraction = sum(r["generations_ran"] / params["generations"] for r in rows) / len(rows)
        trial.set_user_attr("generation_fraction", generation_fraction)
        # Small prespecified computation cost encourages efficient stopping at similar statistical loss.
        return mse + q95 + 0.02 * generation_fraction

    study.optimize(objective, n_trials=args.trials)
    (root / "best_trial.json").write_text(json.dumps({
        "engine": args.engine, "family": args.family,
        "best_params": study.best_params, "pilot_score": study.best_value,
        "status": "pilot_only_not_confirmatory",
        "validation": "three grouped mechanism folds with two-metric mean-reference ratios",
    }, indent=2), encoding="utf-8")
    print(json.dumps({"best_value": study.best_value, "best_params": study.best_params}))


if __name__ == "__main__":
    main()
