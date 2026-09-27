
def commits [count: int, skip: int, revision: string] {
    # everything else outside this function was written by a clanker
    git -c color.ui=false log $revision -z --no-show-signature --max-count $count --skip $skip --format='%h%x00%an%x00%G?%x00%ad%x00%s' --date=format:'%H:%M %Y/%m/%d'
  | split row (char nul)
  | drop 1
  | chunks 5
  | each {
        |row|
        let commit = ([hash user sign time msg] | zip $row | into record)
        $commit | update sign { |commit|
            match $commit.sign {
                G => 'good'
                B => 'bad'
                U => 'good-unknown'
                X => 'good-expired'
                Y => 'good-expired-key'
                R => 'good-revoked-key'
                E => 'cannot-check'
                N => 'unsigned'
                _ => $commit.sign
            }
        }
    }
}

export def main [count?: int, --page] {
    let initial_count = if $count == null { if $page { 1 } else { 3 } } else { $count }
    if $initial_count < 1 {
        error make 'count must be greater than zero'
    }

    if $page {
        let revision = (git rev-parse HEAD | str trim)
        print --stderr 'Enter: next commit; q: quit'

        generate { |skip|
            let continue = if $skip < $initial_count {
                true
            } else {
                (input --numchar 1 --suppress-output | str lowercase) != 'q'
            }

            if $continue {
                let batch = (commits 1 $skip $revision)
                if ($batch | is-empty) { {} } else {
                    {out: ($batch | first), next: ($skip + 1)}
                }
            } else { {} }
        } 0
    } else {
        commits $initial_count 0 HEAD
    }
}
