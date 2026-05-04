# dotfiles

## setup

1. 新PC環境で
```
chezmoi init https://github.com/okdyy75/dotfiles.git
```


2. ユーザー名を直接指定している箇所を書き換え

3. 新PC環境に反映
```
chezmoi apply
```

## other

一部ファイルだけコピー

```
curl --create-dirs -o ~/.agents/skills/knowledge/SKILL.md \
  https://raw.githubusercontent.com/okdyy75/dotfiles/refs/heads/main/dot_agents/skills/knowledge/SKILL.md
```
