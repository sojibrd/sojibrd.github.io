export const SPORT_META = {
  cricket: {
    positions: ['Batsman','Bowler','All-Rounder','Wicket-Keeper'],
    skills: [
      'Right-Handed Batsman','Left-Handed Batsman',
      'Right-Arm Fast Bowler','Left-Arm Fast Bowler',
      'Right-Arm Medium Pacer','Left-Arm Medium Pacer',
      'Right-Arm Off Spinner','Left-Arm Orthodox Spinner',
      'Right-Arm Leg Spinner','Chinaman Bowler',
      'Swing Bowler','Seam Bowler','Direct-Hit Specialist',
      'Captain','Vice Captain','Team Strategist',
      'Bowling Coordinator','Batting Coordinator',
      'Opening Batsman','Top-Order Batsman','Middle-Order Batsman',
      'Lower-Order Batsman','Finisher','Power Hitter','Part-Time Batsman',
      'Batting All-Rounder','Bowling All-Rounder',
      'Opening Bowler','Death Over Specialist','Part-Time Bowler',
      'Wicket Keeper','Boundary Fielder','Slip Fielder',
      'Close-In Fielder','Outfield Specialist',
    ],
    roles: ['CricketScorer','CricketUmpire','CricketVideoStreamer'],
  },
  football: {
    positions: [
      'Goalkeeper (GK)','Center Back (CB)','Left Back (LB)','Right Back (RB)',
      'Wing Back (LWB / RWB)','Defensive Midfielder (CDM)','Central Midfielder (CM)',
      'Attacking Midfielder (CAM)','Left Midfielder (LM)','Right Midfielder (RM)',
      'Left Winger (LW)','Right Winger (RW)','Striker (ST)','Center Forward (CF)',
      'Utility Player',
    ],
    skills: [
      'Dribbling','First Touch','Ball Control','Short Passing','Long Passing',
      'Vision','Finishing','Long Shots','Shot Power','Volleys',
      'Speed','Acceleration','Strength','Stamina','Tackling',
      'Interceptions','Marking','Heading','Playmaking','Positioning',
      'Crossing','Free Kick','Penalty Taking','Shot Stopping','Reflexes',
      'Distribution',
    ],
    roles: ['FootballReferee','FootballScorer','FootballCoach','FootballVideoStreamer'],
  },
  hockey:     { positions: ['Goalkeeper','Defender','Midfielder','Forward'],                                                                             skills: ['Stick Handling','Passing','Shooting','Defending'],                            roles: ['HockeyReferee','HockeyCoach','HockeyVideoStreamer'] },
  tennis:     { positions: ['Singles','Doubles'],                                                                                                        skills: ['Forehand','Backhand','Serve','Volley'],                                       roles: ['TennisUmpire','TennisCoach','TennisVideoStreamer'] },
  basketball: { positions: ['Point Guard','Shooting Guard','Small Forward','Power Forward','Center'],                                                    skills: ['Dribbling','Passing','Shooting','Defending'],                                 roles: ['BasketballReferee','BasketballCoach','BasketballVideoStreamer'] },
  badminton:  { positions: ['Singles','Doubles','Mixed Doubles'],                                                                                        skills: ['Smash','Drop Shot','Clear','Net Play'],                                       roles: ['BadmintonReferee','BadmintonCoach','BadmintonVideoStreamer'] },
  rugby:      { positions: ['Prop','Hooker','Lock','Flanker','Number 8','Scrum-Half','Fly-Half','Centre','Winger','Fullback'],                           skills: ['Tackling','Passing','Kicking','Sprinting'],                                  roles: ['RugbyReferee','RugbyCoach','RugbyVideoStreamer'] },
  baseball:   { positions: ['Pitcher','Catcher','First Base','Second Base','Third Base','Shortstop','Left Field','Center Field','Right Field'],          skills: ['Pitching','Batting','Fielding','Base Running'],                               roles: ['BaseballUmpire','BaseballCoach','BaseballVideoStreamer'] },
};

export const ALL_SPORTS = [
  { key: 'cricket',    label: 'Cricket',    emoji: '🏏' },
  { key: 'football',   label: 'Football',   emoji: '⚽' },
  { key: 'hockey',     label: 'Hockey',     emoji: '🏑' },
  { key: 'tennis',     label: 'Tennis',     emoji: '🎾' },
  { key: 'basketball', label: 'Basketball', emoji: '🏀' },
  { key: 'badminton',  label: 'Badminton',  emoji: '🏸' },
  { key: 'rugby',      label: 'Rugby',      emoji: '🏉' },
  { key: 'baseball',   label: 'Baseball',   emoji: '⚾' },
];

export function fmt(val, fallback = '—') {
  if (val === null || val === undefined || val === '') return fallback;
  return val;
}

export function humanize(str) {
  if (!str) return '';
  return str
    .replace(/([A-Z])/g, ' $1')
    .replace(/^./, (c) => c.toUpperCase())
    .trim();
}

const SPORT_PREFIX_RE = /^(Cricket|Football|Hockey|Tennis|Basketball|Badminton|Rugby|Baseball)/;
export function parseRole(roleObj) {
  const key = Object.keys(roleObj)[0];
  return { name: humanize(key.replace(SPORT_PREFIX_RE, '')), fee: roleObj[key] };
}
