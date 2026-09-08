-- 0028 and 0029 were edited after they had shipped (b2473dd). Databases
-- that applied the originals lack these three objects; elsewhere this is
-- a no-op.
ALTER TABLE effect_runs
    ADD COLUMN IF NOT EXISTS owner TEXT NOT NULL GENERATED ALWAYS AS (
        CASE
            WHEN kind IN ('push', 'check') THEN 'build'
            WHEN kind = 'schedule' THEN 'schedule'
            ELSE 'delivery'
        END
    ) STORED;
ALTER TABLE effect_runs ADD COLUMN IF NOT EXISTS lock TEXT;
CREATE TABLE IF NOT EXISTS effect_eval_errors (
    build_id BIGINT NOT NULL REFERENCES builds (id) ON DELETE CASCADE,
    source TEXT NOT NULL,
    error TEXT NOT NULL,
    code_rev TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (build_id, source)
);
