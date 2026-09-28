# bash-mommy
Yet another [Gankra/cargo-mommy](https://github.com/Gankra/cargo-mommy) implementation. 

Inspired by [sudofox/shell-mommy](https://github.com/sudofox/shell-mommy).

I mainly wanted to add the ability to fetch responses directly from the upstream so I can have the more *wild* options there

## Requirements
- bash 4.4 or newer
- `curl`
- `jq` may be installed but if not,should be fetched automatically from [jqlang/jq](https://github.com/jqlang/jq/releases) (Linux only)

Responses are fetched from upstream on first use and refreshed once a week. Run `mommy_update` to refresh them.

## Installation
If you just want `mommy` in your shell when you want it, simply source `mommy.sh`

```bash
$ source mommy.sh
$ mommy false
don't forget to hydrate~ 💖
```

If you are more deranged, use `PROMPT_COMMAND`
```bash
$ source mommy.sh
$ PROMPT_COMMAND="mommy_status${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
$ false
it's ok, mommy's here for you~ 💖
```

## Configuration
The following settings are available to you:

- `BASH_MOMMY_MOOD`: `chill`, `ominous`, `thirsty` or `yikes`. Defaults to `chill`
- `BASH_MOMMY_PRONOUN`: Defaults to `her`
- `BASH_MOMMY_ROLE`: Defaults to `mommy`
- `BASH_MOMMY_AFFECTIONATE_TERM`: Defaults to `girl`

The following only becomes available if `BASH_MOMMY_MOOD` is `yikes`
- `BASH_MOMMY_PART`
- `BASH_MOMMY_DENIGRATING_TERM`

(You can figure them out yourself)

Set `MOMMY_SESSION_DISABLED=true` to make mommy quiet for the rest of the session.
