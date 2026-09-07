_: {
  programs.bash = {
    enable = true;
    initExtra = ''
      export VISUAL="vi"
      export EDITOR="$VISUAL"

      # prompt
      if [ -z "$name" ]; then
          PS1="\[\e[31m\]┌───(\u@\h) \[\e[37m\]\w\n\[\e[31m\]└─§> \[\e[0m\]"
      else
          PS1="\[\e[92m\]┌───(\u@''${name}) \[\e[37m\]\w\n\[\e[92m\]└─§> \[\e[0m\]"
      fi
    '';
  };
}
