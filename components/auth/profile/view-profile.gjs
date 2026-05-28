import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { fn } from '@ember/helper';
import { or, eq } from 'ember-truth-helpers';
import { concat } from '@ember/helper';
import { tracked } from '@glimmer/tracking';
import { action } from '@ember/object';
import { service } from '@ember/service';
import { htmlSafe } from '@ember/template';
import config from 'spordium/config/environment';
import lucideIcon from 'spordium/helpers/lucide-icon';
import ImageUploader from 'spordium/components/ui/image-uploader';
import CricketProfile from './sports/cricket-profile';
import FootballProfile from './sports/football-profile';
import SportProfileForm from './sports/sport-profile-form';
import SportGallery from './sports/sport-gallery';
import { SPORT_META, ALL_SPORTS } from './sport-meta';

export default class ViewProfileComponent extends Component {
  @service session;
  @service toast;

  host = config.APP.S3_BUCKET_URL + '/';

  _boyIdx  = Math.floor(Math.random() * 3);
  _girlIdx = Math.floor(Math.random() * 2);

  get defaultAvatar() {
    const gender = (this.args.profile?.user_gender ?? '').toLowerCase();
    const isFemale = gender === 'female' || gender === 'f';
    if (isFemale) {
      return ['/assets/avatar/girl (1).webp', '/assets/avatar/girl (2).webp'][this._girlIdx];
    }
    return ['/assets/avatar/boy (1).webp', '/assets/avatar/boy (2).webp', '/assets/avatar/boy (3).webp'][this._boyIdx];
  }

  @tracked activeTab        = 'general';
  @tracked cricketStatsTab  = 'batting';
  @tracked _sportData       = {};
  @tracked _addedSports     = [];

  @tracked showSportPicker   = false;
  @tracked showPhotoUploader = false;
  @tracked _uploadContext    = 'general';
  @tracked showProfileForm   = false;
  @tracked selectedSport     = null;
  @tracked profilePic        = null;
  @tracked nickName          = '';
  @tracked jerseyNumber      = '';
  @tracked playingPosition   = '';
  @tracked selectedSkills      = [];
  @tracked selectedPositions   = [];
  @tracked matchFee            = '';
  @tracked tournamentFee       = '';
  @tracked roleRows            = [{ role: '', fee: 0 }];
  @tracked skillSearch         = '';
  @tracked showSkillDropdown   = false;
  @tracked positionSearch      = '';
  @tracked showPositionDropdown = false;
  @tracked careerHighlights    = [''];
  @tracked isSaving            = false;
  @tracked saveError           = null;
  @tracked isEditMode          = false;
  @tracked _originalData       = null;
  @tracked _coverVisible       = true;

  // ── computed ─────────────────────────────────────────────────────────────

  get _allExistingKeys() {
    const fromProfile = (this.args.profile?.user_playing_sports ?? []).map(s => s.toLowerCase());
    return [...new Set([...fromProfile, ...this._addedSports])];
  }

  get availableSports() {
    const existing = this._allExistingKeys;
    // Only cricket is ready; other sports are coming soon
    return ALL_SPORTS.filter(s => s.key === 'cricket' && !existing.includes(s.key));
  }

  get sportMeta() {
    return SPORT_META[this.selectedSport?.key] ?? { positions: [], skills: [], roles: [] };
  }

  get filteredSkillOptions() {
    const q = this.skillSearch.toLowerCase().trim();
    return this.sportMeta.skills.filter(s =>
      !this.selectedSkills.includes(s) &&
      (q === '' || s.toLowerCase().includes(q))
    );
  }

  get filteredPositionOptions() {
    const q = this.positionSearch.toLowerCase().trim();
    return this.sportMeta.positions.filter(p =>
      !this.selectedPositions.includes(p) &&
      (q === '' || p.toLowerCase().includes(q))
    );
  }

  get sportTabs() {
    return this._allExistingKeys
      .filter(key => key === 'cricket')
      .map((key) => {
        const meta = ALL_SPORTS.find(s => s.key === key);
        return { key, label: meta?.label ?? (key.charAt(0).toUpperCase() + key.slice(1)) };
      });
  }

  get isOwnProfile() {
    return this.session.isOwnProfile(this.args.profile?.user_username);
  }

  get isActiveSportTab() { return this.activeTab !== 'general'; }

  get currentSportData() { return this._sportData[this.activeTab] ?? {}; }

  get loadingSport() { return this.currentSportData.loading ?? false; }
  get sportError()   { return this.currentSportData.error   ?? null;  }
  get sportLoaded()  { return this.currentSportData.loaded  ?? false; }

  get cp() { return this.currentSportData.profile ?? {}; }

  get hasChanges() {
    if (!this.isEditMode || !this._originalData) return true;
    const orig = this._originalData;
    if (this.nickName !== orig.nickName) return true;
    if (this.jerseyNumber !== orig.jerseyNumber) return true;
    if (this.playingPosition !== orig.playingPosition) return true;
    if (String(this.matchFee) !== String(orig.matchFee)) return true;
    if (String(this.tournamentFee) !== String(orig.tournamentFee)) return true;
    if (this.profilePic !== null) return true;
    if (this.selectedSkills.length !== orig.selectedSkills.length) return true;
    if (this.selectedSkills.some(s => !orig.selectedSkills.includes(s))) return true;
    if (this.selectedPositions.length !== (orig.selectedPositions ?? []).length) return true;
    if (this.selectedPositions.some(p => !(orig.selectedPositions ?? []).includes(p))) return true;
    if (this.roleRows.length !== orig.roleRows.length) return true;
    for (let i = 0; i < this.roleRows.length; i++) {
      if (this.roleRows[i].role !== orig.roleRows[i]?.role) return true;
      if (String(this.roleRows[i].fee) !== String(orig.roleRows[i]?.fee)) return true;
    }
    const origHighlights = orig.careerHighlights ?? [''];
    if (this.careerHighlights.join('|') !== origHighlights.join('|')) return true;
    return false;
  }

  get saveDisabled() { return this.isSaving || !this.hasChanges; }

  @action handleProfileImgError(event) {
    event.target.onerror = null;
    event.target.src = this.defaultAvatar;
  }

  get coverPortionStyle() {
    return htmlSafe(
      this._coverVisible
        ? 'max-height: 350px; overflow: hidden; transition: max-height 0.45s cubic-bezier(0.4, 0, 0.2, 1);'
        : 'max-height: 0px; overflow: hidden; transition: max-height 0.45s cubic-bezier(0.4, 0, 0.2, 1);'
    );
  }

  // ── actions ──────────────────────────────────────────────────────────────

  @action openSportPicker()        { this.showSportPicker = true; }
  @action openPhotoUploader()      { this._uploadContext = 'general'; this.showPhotoUploader = true; }
  @action openSportPhotoUploader() { this._uploadContext = 'sport'; this.showPhotoUploader = true; }
  @action closePhotoUploader()     { this.showPhotoUploader = false; }

  @action async handlePhotoChange(result) {
    if (!result?.objectToken) return;
    if (this._uploadContext === 'sport') {
      await this.saveSportProfilePhoto(result.objectToken);
    } else {
      await this.saveProfilePhoto(result.objectToken);
    }
  }

  async saveProfilePhoto(objectToken) {
    try {
      const existingPhoto = this.args.profile?.user_primary_pic;
      const payload = { user_primary_pic: objectToken };
      //if (existingPhoto) payload.old_primary_photo = existingPhoto;
      const res = await fetch(`${config.APP.API_HOST}/auth_user/edit_profile/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.session.token}` },
        body: JSON.stringify(payload),
      });
      if (!res.ok) { const err = await res.text(); throw new Error(err || 'Upload failed'); }
      this.session.updateProfilePic(objectToken);
      this.toast.success('Profile Upload Succeed');
      this.showPhotoUploader = false;
      await this.args.onProfileRefresh?.();
    } catch (err) {
      this.toast.error(err.message || 'Failed to save profile photo');
    }
  }

  async saveSportProfilePhoto(objectToken) {
    try {
      const oldPic = this.cp?.player_primary_pic;
      const payload = { sports: this.activeTab, user_primary_photo: objectToken };
      if (oldPic && !oldPic.endsWith('//') && oldPic.trim() !== '') {
        payload.old_primary_photo = oldPic;
      }
      const res = await fetch(`${config.APP.API_HOST}/auth_user/sports-primary-picture/`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'Authorization': `Bearer ${this.session.token}` },
        body: JSON.stringify(payload),
      });
      if (!res.ok) { const err = await res.text(); throw new Error(err || 'Upload failed'); }
      this.toast.success('Profile Upload Succeed');
      this.showPhotoUploader = false;
      const sport = this.activeTab;
      this._sportData = { ...this._sportData, [sport]: { loading: false, error: null, loaded: false, profile: null, stats: null, bowlingStats: null, fieldingStats: null, overallStats: null } };
      await this.fetchDistinctSportsData(sport);
    } catch (err) {
      this.toast.error(err.message || 'Failed to save sport profile photo');
    }
  }

  @action closeSportPicker() { this.showSportPicker = false; }

  @action selectSport(sport) {
    this.selectedSport     = sport;
    this.showSportPicker   = false;
    this.showProfileForm   = true;
    this.profilePic        = null;
    this.nickName          = '';
    this.jerseyNumber      = '';
    this.playingPosition   = '';
    this.selectedSkills      = [];
    this.selectedPositions   = [];
    this.matchFee            = '';
    this.tournamentFee       = '';
    this.roleRows            = [{ role: '', fee: 0 }];
    this.skillSearch         = '';
    this.showSkillDropdown   = false;
    this.positionSearch      = '';
    this.showPositionDropdown = false;
    this.careerHighlights    = [''];
  }

  @action openEditSportForm() {
    const sport = ALL_SPORTS.find(s => s.key === this.activeTab);
    if (!sport) return;
    const cp = this.cp;
    this.selectedSport   = sport;
    this.isEditMode      = true;
    this.nickName        = cp.player_nickname ?? '';
    this.jerseyNumber    = cp.jersey_number != null ? String(cp.jersey_number) : '';
    this.playingPosition = cp.playing_position ?? '';
    const meta = SPORT_META[sport.key] ?? { positions: [], skills: [], roles: [] };
    const rawSkills = cp.skills ?? [];
    this.selectedSkills = meta.skills.filter(metaSkill =>
      rawSkills.some(s =>
        s === metaSkill ||
        s.replace(/\s+/g, '').toLowerCase() === metaSkill.replace(/\s+/g, '').toLowerCase()
      )
    );
    this.matchFee      = cp.match_fee != null ? String(cp.match_fee) : '';
    this.tournamentFee = cp.tournament_fee != null ? String(cp.tournament_fee) : '';
    this.roleRows      = (cp.user_roles ?? []).length
      ? (cp.user_roles ?? []).map(r => { const key = Object.keys(r)[0]; return { role: this._displayRoleName(key), fee: r[key] }; })
      : [{ role: '', fee: 0 }];
    const rawPositions = Array.isArray(cp.playing_position) ? cp.playing_position : (cp.playing_position ? [cp.playing_position] : []);
    const posMeta = SPORT_META[sport.key]?.positions ?? [];
    this.selectedPositions = posMeta.filter(metaPos =>
      rawPositions.some(p =>
        p === metaPos ||
        p.replace(/\s+/g, '').toLowerCase() === metaPos.replace(/\s+/g, '').toLowerCase()
      )
    );
    this.careerHighlights     = (cp.career_highlights ?? []).length > 0 ? [...cp.career_highlights] : [''];
    this.skillSearch          = '';
    this.showSkillDropdown    = false;
    this.positionSearch       = '';
    this.showPositionDropdown = false;
    this.profilePic           = null;
    this.saveError            = null;
    this._originalData = {
      nickName:          this.nickName,
      jerseyNumber:      this.jerseyNumber,
      playingPosition:   this.playingPosition,
      selectedSkills:    [...this.selectedSkills],
      selectedPositions: [...this.selectedPositions],
      matchFee:          this.matchFee,
      tournamentFee:     this.tournamentFee,
      roleRows:          this.roleRows.map(r => ({ ...r })),
      careerHighlights:  [...this.careerHighlights],
    };
    this.showProfileForm = true;
  }

  @action closeProfileForm() {
    this.showProfileForm      = false;
    this.selectedSport        = null;
    this.isEditMode           = false;
    this._originalData        = null;
    this.skillSearch          = '';
    this.showSkillDropdown    = false;
    this.positionSearch       = '';
    this.showPositionDropdown = false;
    this.selectedPositions    = [];
    this.careerHighlights     = [''];
  }

  @action addRoleRow() { this.roleRows = [...this.roleRows, { role: '', fee: 0 }]; }

  @action removeRoleRow(index) {
    this.roleRows = this.roleRows.filter((_, i) => i !== index);
  }

  @action updateField(field, event) { this[field] = event.target.value; }

  @action selectSkill(skill, event) {
    event?.preventDefault();
    if (!this.selectedSkills.includes(skill)) {
      this.selectedSkills = [...this.selectedSkills, skill];
    }
    this.skillSearch = '';
  }

  @action removeSkillTag(skill) {
    this.selectedSkills = this.selectedSkills.filter(s => s !== skill);
  }

  @action updateSkillSearch(event) {
    this.skillSearch       = event.target.value;
    this.showSkillDropdown = true;
  }

  @action openSkillDropdown()  { this.showSkillDropdown = true; }
  @action closeSkillDropdown() { this.showSkillDropdown = false; }

  @action toggleSkillDropdown(event) {
    event?.preventDefault();
    this.showSkillDropdown = !this.showSkillDropdown;
  }

  @action selectPosition(position, event) {
    event?.preventDefault();
    if (!this.selectedPositions.includes(position)) {
      this.selectedPositions = [...this.selectedPositions, position];
    }
    this.positionSearch = '';
  }

  @action removePositionTag(position) {
    this.selectedPositions = this.selectedPositions.filter(p => p !== position);
  }

  @action updatePositionSearch(event) {
    this.positionSearch       = event.target.value;
    this.showPositionDropdown = true;
  }

  @action openPositionDropdown()  { this.showPositionDropdown = true; }
  @action closePositionDropdown() { this.showPositionDropdown = false; }

  @action togglePositionDropdown(event) {
    event?.preventDefault();
    this.showPositionDropdown = !this.showPositionDropdown;
  }

  @action addHighlight() { this.careerHighlights = [...this.careerHighlights, '']; }

  @action removeHighlight(index) {
    this.careerHighlights = this.careerHighlights.filter((_, i) => i !== index);
  }

  @action updateHighlight(index, event) {
    this.careerHighlights = this.careerHighlights.map((h, i) => i === index ? event.target.value : h);
  }

  @action updateRoleField(index, field, event) {
    this.roleRows = this.roleRows.map((row, i) =>
      i === index ? { ...row, [field]: event.target.value } : row
    );
  }

  get _authHeaders() {
    return { 'Authorization': `Bearer ${this.session.token}`, 'Content-Type': 'application/json' };
  }

  _apiRoleName(role) {
    return role === 'CricketUmpire' ? 'CricketUmipire' : role;
  }

  _displayRoleName(role) {
    return role === 'CricketUmipire' ? 'CricketUmpire' : role;
  }

  async _sha256Base64(file) {
    const buf   = await file.arrayBuffer();
    const hash  = await crypto.subtle.digest('SHA-256', buf);
    const bytes = new Uint8Array(hash);
    return btoa(String.fromCharCode(...bytes));
  }

  async _apiPost(path, body) {
    const base = config.APP.API_HOST;
    const res  = await fetch(`${base}${path}`, {
      method:  'POST',
      headers: this._authHeaders,
      body:    JSON.stringify(body),
    });
    if (!res.ok) {
      const text = await res.text().catch(() => res.statusText);
      throw new Error(text || `POST ${path} failed (${res.status})`);
    }
    return res.json();
  }

  @action async saveSportsProfile(event) {
    event.preventDefault();
    if (this.isSaving) return;

    const sport = this.selectedSport;

    if (sport?.key === 'football') {
      const errors = [];
      if (!this.nickName.trim())          errors.push('Nick Name is required.');
      if (!this.jerseyNumber.trim())      errors.push('Jersey Number is required.');
      if (!this.selectedPositions.length) errors.push('Select at least one Playing Position.');
      if (!this.selectedSkills.length)    errors.push('Select at least one Skill.');
      if (errors.length) { this.saveError = errors.join(' '); return; }
    }

    this.isSaving  = true;
    this.saveError = null;

    const userId = this.args.profile?.userid;
    const base   = config.APP.API_HOST;

    try {
      if (this.isEditMode) {
        const orig = this._originalData;
        const sportPayload = {
          sports_name:     sport.key,
          player_nickname: this.nickName,
          match_fee:       Number(this.matchFee) || 0,
          tournament_fee:  Number(this.tournamentFee) || 0,
        };
        if (sport.key === 'football') {
          sportPayload.football_skills  = this.selectedSkills;
          sportPayload.playing_position = this.selectedPositions;
          sportPayload.jersey_number    = this.jerseyNumber;
        } else {
          sportPayload.skills = this.selectedSkills;
        }
        const highlights = this.careerHighlights.filter(h => h.trim());
        if (highlights.length > 0) sportPayload.career_highlights = highlights;

        await this._apiPost('/auth_user/update_playing_sports/', {
          userid: userId,
          user_playing_sports: [sportPayload],
        });

        const origRoleMap  = {};
        (orig.roleRows ?? []).forEach(r => { if (r.role) origRoleMap[r.role] = Number(r.fee) || 0; });
        const validRoles   = this.roleRows.filter(r => r.role);
        const currentNames = new Set(validRoles.map(r => r.role));
        const remove_roles = Object.keys(origRoleMap).filter(name => !currentNames.has(name));
        const added_roles  = validRoles.filter(r =>
          !(r.role in origRoleMap) || Number(r.fee) !== origRoleMap[r.role]
        );
        if (remove_roles.length) await this._apiPost('/auth_user/add-officers-role/', { remove_roles: remove_roles.map(n => this._apiRoleName(n)) });
        if (added_roles.length) {
          await this._apiPost('/auth_user/add-officers-role/', {
            added_roles: added_roles.map(r => ({ [this._apiRoleName(r.role)]: Number(r.fee) || 0 })),
          });
        }

        this.closeProfileForm();
        this.toast.success(`${sport.label} profile updated!`);
        this._sportData = { ...this._sportData, [sport.key]: { loading: false, error: null, loaded: false, profile: null, stats: null, bowlingStats: null, fieldingStats: null, overallStats: null } };
        await this.fetchDistinctSportsData(sport.key);

      } else {
        const createPayload = {
          sports_name:     sport.key,
          player_nickname: this.nickName,
          match_fee:       Number(this.matchFee)      || 0,
          tournament_fee:  Number(this.tournamentFee) || 0,
        };
        if (sport.key === 'football') {
          createPayload.football_skills  = this.selectedSkills;
          createPayload.playing_position = this.selectedPositions;
          createPayload.jersey_number    = this.jerseyNumber;
        } else {
          createPayload.skills = this.selectedSkills;
        }
        await this._apiPost('/auth_user/update_playing_sports/', {
          userid: userId,
          user_playing_sports: [createPayload],
        });

        const validRoles = this.roleRows.filter(r => r.role);
        if (validRoles.length) {
          await this._apiPost('/auth_user/add-officers-role/', {
            added_roles: validRoles.map(r => ({ [this._apiRoleName(r.role)]: Number(r.fee) || 0 })),
          });
        }

        if (this.profilePic) {
          const ext        = this.profilePic.type.split('/')[1] || 'jpeg';
          const checksum   = await this._sha256Base64(this.profilePic);
          const uploadData = await this._apiPost('/auth_user/initiate-upload-auth/', {
            type: sport.key, images: { image1: ext }, checksums: { image1: checksum },
          });
          const slot = uploadData.upload_slots?.image1;
          if (!slot?.upload_url) throw new Error('Upload slot not returned by server');
          const s3Res = await fetch(slot.upload_url, {
            method:  'PUT',
            headers: { ...slot.headers, 'x-amz-tagging': 'status=permanent' },
            body:    this.profilePic,
          });
          if (!s3Res.ok) throw new Error(`S3 upload failed (${s3Res.status})`);
          await this._apiPost('/auth_user/sports-primary-picture/', {
            sports: sport.key, user_primary_photo: slot.object_token,
          });
        }

        await fetch(`${base}/auth_user/get_playing_sports/General/${userId}/`, {
          headers: { 'Authorization': `Bearer ${this.session.token}` },
        });

        if (!this._addedSports.includes(sport.key)) {
          this._addedSports = [...this._addedSports, sport.key];
        }

        this.closeProfileForm();
        this.toast.success(`${sport.label} profile created!`);
        await this.switchTab(sport.key);
      }
    } catch (err) {
      this.saveError = err.message || 'Something went wrong. Please try again.';
      this.toast.error(this.saveError);
    } finally {
      this.isSaving = false;
    }
  }

  @action async switchTab(tab) {
    if (tab === 'general') {
      this.activeTab = tab;
      this._coverVisible = true;
    } else {
      if (this.activeTab === 'general') this._coverVisible = false;
      this.activeTab = tab;
    }
    if (tab === 'cricket') this.cricketStatsTab = 'batting';
    if (tab !== 'general') {
      const existing = this._sportData[tab] ?? {};
      if (!existing.loaded && !existing.loading) {
        await this.fetchDistinctSportsData(tab);
      }
    }
  }

  @action async fetchDistinctSportsData(sport) {
    const userId = this.args.profile?.userid;
    if (!userId) {
      this._sportData = { ...this._sportData, [sport]: { loading: false, error: 'User ID not available', loaded: false, profile: null, stats: null } };
      return;
    }

    this._sportData = { ...this._sportData, [sport]: { loading: true, error: null, loaded: false, profile: null, stats: null, bowlingStats: null, fieldingStats: null, overallStats: null } };

    const isCricket    = sport === 'cricket';
    const authHeaders  = { 'Authorization': `Bearer ${this.session.token}` };
    const base         = config.APP.API_HOST;

    try {
      const requests = [
        fetch(`${base}/auth_user/get_playing_sports/${sport}/${userId}/`, { headers: authHeaders }),
        isCricket ? fetch(`${base}/auth_user/get_player_batting_history/${userId}/`,  { headers: authHeaders }) : Promise.resolve(null),
        isCricket ? fetch(`${base}/auth_user/get_player_bowling_history/${userId}/`,  { headers: authHeaders }) : Promise.resolve(null),
        isCricket ? fetch(`${base}/auth_user/get_player_filding_history/${userId}/`,  { headers: authHeaders }) : Promise.resolve(null),
        isCricket ? fetch(`${base}/auth_user/get_player_overall_history/${userId}/`,  { headers: authHeaders }) : Promise.resolve(null),
      ];
      const [sportRes, battingRes, bowlingRes, fieldingRes, overallRes] = await Promise.all(requests);

      let profile = null, stats = null, bowlingStats = null, fieldingStats = null, overallStats = null;

      if (sportRes?.ok)   { const j = await sportRes.json();   profile      = j.data ?? null; }
      if (battingRes?.ok) { const j = await battingRes.json(); stats        = Array.isArray(j.data) ? (j.data[0] ?? null) : (j.data ?? null); }
      if (bowlingRes?.ok) { const j = await bowlingRes.json(); bowlingStats = Array.isArray(j.data) ? (j.data[0] ?? null) : (j.data ?? null); }
      if (fieldingRes?.ok){ const j = await fieldingRes.json();fieldingStats= Array.isArray(j.data) ? (j.data[0] ?? null) : (j.data ?? null); }
      if (overallRes?.ok) { const j = await overallRes.json(); overallStats = Array.isArray(j.data) ? (j.data[0] ?? null) : (j.data ?? null); }

      this._sportData = { ...this._sportData, [sport]: { loading: false, error: null, loaded: true, profile, stats, bowlingStats, fieldingStats, overallStats } };
    } catch (err) {
      this._sportData = { ...this._sportData, [sport]: { loading: false, error: err.message || `Failed to load ${sport} data`, loaded: false, profile: null, stats: null, bowlingStats: null, fieldingStats: null, overallStats: null } };
    }
  }

  <template>
    <div class="overflow-hidden rounded-3xl bg-white dark:bg-gray-900 shadow-xl ring-1 ring-gray-200 dark:ring-gray-700">

      {{! ── HEADER ── }}
      <div style={{this.coverPortionStyle}}>
        <div class="h-36 w-full bg-gradient-to-r from-indigo-600 via-blue-600 to-violet-600 md:h-44 relative overflow-hidden">
          <div class="absolute inset-0 opacity-10"
            style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 32px 32px;">
          </div>
        </div>
        <div class="relative px-4 sm:px-6 md:px-10 pb-3">
          <div class="relative -mt-14 sm:-mt-16 flex flex-col items-center gap-4 md:flex-row md:items-end md:gap-6">
            <div class="relative shrink-0">
              {{!-- Verification paused: img src used verify_img_status to pick between user_primary_pic (verified) and user_primary_pic (unverified)
              <img
                src={{if
                  @profile.verify_img_status
                  (if @profile.user_primary_pic (concat this.host @profile.user_primary_pic) this.defaultAvatar)
                  (if @profile.user_primary_pic (concat this.host @profile.user_primary_pic) this.defaultAvatar)
                }}
                style="transform: scaleX(-1)"
                class="h-28 w-28 sm:h-32 sm:w-32 md:h-36 md:w-36 rounded-2xl border-4 border-white dark:border-gray-900 object-cover shadow-2xl"
                alt="Profile photo"
              />
              --}}
              <img
                src={{if @profile.user_primary_pic (concat this.host @profile.user_primary_pic) this.defaultAvatar}}
                style="transform: scaleX(-1)"
                class="h-28 w-28 sm:h-32 sm:w-32 md:h-36 md:w-36 rounded-2xl border-4 border-white dark:border-gray-900 object-cover shadow-2xl"
                alt="Profile photo"
                {{on "error" this.handleProfileImgError}}
              />
              {{!-- Verification paused: badge + conditional upload button
              {{#if @profile.verify_img_status}}
                <span class="absolute -bottom-2 -right-2 z-10 inline-flex items-center gap-1 bg-green-500 text-white text-[10px] font-bold px-2 py-0.5 rounded-full shadow-md uppercase tracking-wide">
                  ✓ Verified
                </span>
              {{else}}
                <button type="button" {{on "click" this.openPhotoUploader}}
                  class="absolute -bottom-2 -right-2 flex items-center justify-center w-8 h-8 rounded-full bg-indigo-600 hover:bg-indigo-500 active:scale-95 text-white shadow-lg transition-all duration-200 ring-2 ring-white dark:ring-gray-900"
                  aria-label="Upload profile photo">
                  {{lucideIcon "upload" size=15}}
                </button>
              {{/if}}
              --}}
              <button type="button" {{on "click" this.openPhotoUploader}}
                class="absolute -bottom-2 -right-2 flex items-center justify-center w-8 h-8 rounded-full bg-indigo-600 hover:bg-indigo-500 active:scale-95 text-white shadow-lg transition-all duration-200 ring-2 ring-white dark:ring-gray-900"
                aria-label="Upload profile photo">
                {{lucideIcon "upload" size=15}}
              </button>
            </div>
            <div class="flex-1 min-w-0 text-center md:text-left pb-3">
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-2 sm:gap-3">
                <h1 class="text-xl sm:text-2xl md:text-3xl font-extrabold text-gray-900 dark:text-white leading-tight capitalize truncate">
                  {{or @profile.user_fullname.first_name "Guest"}}
                  {{@profile.user_fullname.last_name}}
                </h1>
                {{#if this.isOwnProfile}}
                  <button type="button" {{on "click" this.openSportPicker}}
                    class="inline-flex items-center gap-2 px-4 sm:px-5 py-2 text-xs font-extrabold uppercase tracking-widest
                           bg-gradient-to-r from-green-400 to-emerald-500 hover:from-green-300 hover:to-emerald-400 active:scale-95
                           text-gray-900 rounded-full shadow-lg shadow-emerald-500/40 hover:shadow-emerald-400/60 transition-all duration-200
                           self-center sm:self-auto shrink-0 ring-2 ring-white/30">
                    <span class="flex items-center justify-center w-4 h-4 rounded-full bg-gray-900/20 font-black text-sm leading-none">+</span>
                    Sports Profile
                  </button>
                {{/if}}
              </div>
              <p class="text-indigo-600 dark:text-indigo-400 font-semibold text-sm sm:text-base mt-0.5">@{{@profile.user_username}}</p>
              {{#if @profile.user_playing_city}}
                <p class="text-sm text-gray-400 dark:text-gray-500 mt-1">
                  📍 {{@profile.user_playing_city}}{{#if @profile.user_country}}, {{@profile.user_country}}{{/if}}
                </p>
              {{/if}}
            </div>
          </div>
        </div>
      </div>
      {{#if this.loadingSport}}
        <div class="h-40 md:h-52 w-full bg-gradient-to-br from-gray-900 via-indigo-950 to-gray-900 relative overflow-hidden flex items-center justify-center">
          <div class="absolute inset-0 opacity-5" style="background-image: radial-gradient(circle, white 1px, transparent 1px); background-size: 24px 24px;"></div>
          <div class="relative flex flex-col items-center gap-3">
            <div class="h-12 w-12 animate-spin rounded-full border-4 border-indigo-500/30 border-t-indigo-400"></div>
            <p class="text-indigo-300/60 text-xs font-semibold uppercase tracking-widest">Loading {{this.activeTab}} data…</p>
          </div>
        </div>
      {{/if}}

      {{! ── Tab bar ── }}
      <div class="bg-gray-950 dark:bg-black flex items-center justify-between px-4 md:px-10
        transition-all duration-[450ms] ease-in-out
        {{if this._coverVisible 'mt-4' 'mt-0'}} min-h-[48px]">
        <div class="flex-1 min-w-0 overflow-x-auto no-scrollbar flex items-center">
          <button type="button" {{on "click" (fn this.switchTab "general")}}
            class="relative shrink-0 px-4 py-3 text-sm font-semibold transition-colors duration-200
              {{if (eq this.activeTab 'general') 'text-white' 'text-gray-400 hover:text-gray-200'}}">
            General
            {{#if (eq this.activeTab "general")}}
              <span class="absolute bottom-0 left-0 right-0 h-0.5 bg-indigo-400 rounded-t-full"></span>
            {{/if}}
          </button>
          {{#each this.sportTabs as |tab|}}
            <button type="button" {{on "click" (fn this.switchTab tab.key)}}
              class="relative shrink-0 px-4 py-3 text-sm font-semibold transition-colors duration-200
                {{if (eq this.activeTab tab.key) 'text-white' 'text-gray-400 hover:text-gray-200'}}">
              {{tab.label}}
              {{#if (eq this.activeTab tab.key)}}
                <span class="absolute bottom-0 left-0 right-0 h-0.5 bg-indigo-400 rounded-t-full"></span>
              {{/if}}
            </button>
          {{/each}}
        </div>
        <div class="flex items-center gap-2 py-2 shrink-0 pl-2">
          {{#if @isCurrentUser}}
            <button type="button"
              {{on "click" (if this.isActiveSportTab this.openEditSportForm @onEdit)}}
              class="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-gray-200 border border-gray-600 rounded-lg hover:border-indigo-400 hover:text-indigo-300 transition-colors duration-200">
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" d="M16.862 4.487l1.687-1.688a1.875 1.875 0 112.652 2.652L10.582 16.07a4.5 4.5 0 01-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 011.13-1.897l8.932-8.931z"/>
              </svg>
              <span class="hidden sm:inline">Edit</span>
            </button>
          {{/if}}
        </div>
      </div>

      {{! ── Tab Content ── }}
      {{#if (eq this.activeTab "general")}}
        <div class="px-4 sm:px-6 md:px-10 py-6 sm:py-8">
          <div class="grid grid-cols-1 gap-8 lg:grid-cols-3">

            <div class="space-y-5 lg:col-span-1">
              <section class="rounded-2xl bg-gray-50 dark:bg-gray-800/50 p-5 border border-gray-100 dark:border-gray-700">
                <h3 class="text-[10px] font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-4">Contact & Location</h3>
                <div class="space-y-3 text-sm">
                  {{! Email }}
                  <div class="flex items-center gap-3 text-gray-700 dark:text-gray-300">
                    <span class="w-8 h-8 flex items-center justify-center rounded-lg bg-blue-100 dark:bg-blue-900/30 text-base shrink-0">📧</span>
                    {{#if this.isOwnProfile}}
                      <span class="truncate">{{or @profile.user_email "No email"}}</span>
                    {{else}}
                      <span class="inline-flex items-center gap-1.5 text-xs font-medium text-gray-400 dark:text-gray-500 italic">
                        <svg class="w-3.5 h-3.5 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                        </svg>
                        Private
                      </span>
                    {{/if}}
                  </div>
                  {{! Phone }}
                  <div class="flex items-center gap-3 text-gray-700 dark:text-gray-300">
                    <span class="w-8 h-8 flex items-center justify-center rounded-lg bg-green-100 dark:bg-green-900/30 text-base shrink-0">📞</span>
                    {{#if this.isOwnProfile}}
                      <span>{{or @profile.user_callphone "No phone"}}</span>
                    {{else}}
                      <span class="inline-flex items-center gap-1.5 text-xs font-medium text-gray-400 dark:text-gray-500 italic">
                        <svg class="w-3.5 h-3.5 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                        </svg>
                        Private
                      </span>
                    {{/if}}
                  </div>
                  {{! Address }}
                  <div class="flex items-start gap-3 text-gray-700 dark:text-gray-300">
                    <span class="w-8 h-8 flex items-center justify-center rounded-lg bg-rose-100 dark:bg-rose-900/30 text-base shrink-0 mt-0.5">📍</span>
                    {{#if this.isOwnProfile}}
                      <span>
                        <span class="block">{{or @profile.address "No address"}}</span>
                        {{#if @profile.user_playing_city}}
                          <span class="text-xs text-gray-400 dark:text-gray-500">
                            {{@profile.user_playing_city}}{{#if @profile.user_state_divition}}, {{@profile.user_state_divition}}{{/if}}
                          </span>
                        {{/if}}
                      </span>
                    {{else}}
                      <span>
                        <span class="inline-flex items-center gap-1.5 text-xs font-medium text-gray-400 dark:text-gray-500 italic">
                          <svg class="w-3.5 h-3.5 shrink-0" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" d="M16.5 10.5V6.75a4.5 4.5 0 10-9 0v3.75m-.75 11.25h10.5a2.25 2.25 0 002.25-2.25v-6.75a2.25 2.25 0 00-2.25-2.25H6.75a2.25 2.25 0 00-2.25 2.25v6.75a2.25 2.25 0 002.25 2.25z"/>
                          </svg>
                          Not shared
                        </span>
                        {{#if @profile.user_playing_city}}
                          <span class="block text-xs text-gray-400 dark:text-gray-500 mt-0.5">
                            {{@profile.user_playing_city}}{{#if @profile.user_state_divition}}, {{@profile.user_state_divition}}{{/if}}
                          </span>
                        {{/if}}
                      </span>
                    {{/if}}
                  </div>
                </div>
              </section>

              <section class="rounded-2xl bg-gray-50 dark:bg-gray-800/50 p-5 border border-gray-100 dark:border-gray-700">
                <h3 class="text-[10px] font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-4">Physical Attributes</h3>
                {{#if @profile.user_configuration}}
                  <div class="grid grid-cols-2 gap-3">
                    <div class="p-3 bg-white dark:bg-gray-700 rounded-xl shadow-sm border border-gray-100 dark:border-gray-600 text-center">
                      <span class="block text-xl font-extrabold text-gray-900 dark:text-white">{{@profile.user_configuration.height}}</span>
                      <span class="text-[10px] text-gray-400 uppercase font-medium">{{or @profile.user_configuration.height_unit "cm"}}</span>
                      <span class="block text-[10px] text-gray-400 uppercase mt-0.5">Height</span>
                    </div>
                    <div class="p-3 bg-white dark:bg-gray-700 rounded-xl shadow-sm border border-gray-100 dark:border-gray-600 text-center">
                      <span class="block text-xl font-extrabold text-gray-900 dark:text-white">{{@profile.user_configuration.weight}}</span>
                      <span class="text-[10px] text-gray-400 uppercase font-medium">{{or @profile.user_configuration.weight_unit "kg"}}</span>
                      <span class="block text-[10px] text-gray-400 uppercase mt-0.5">Weight</span>
                    </div>
                  </div>
                  {{#if @profile.user_configuration.body_type}}
                    <p class="mt-3 text-xs text-gray-500 dark:text-gray-400">Body Type: <span class="font-bold text-indigo-600 dark:text-indigo-400">{{@profile.user_configuration.body_type}}</span></p>
                  {{/if}}
                {{else}}
                  <p class="text-xs italic text-gray-400 dark:text-gray-500">Physical data not provided</p>
                {{/if}}
              </section>

              <section class="rounded-2xl bg-gray-50 dark:bg-gray-800/50 p-5 border border-gray-100 dark:border-gray-700">
                <h3 class="text-[10px] font-bold uppercase tracking-widest text-gray-400 dark:text-gray-500 mb-4">Interested Sports</h3>
                <div class="flex flex-wrap gap-2">
                  {{#each @profile.user_interested_sports.all_sports as |sport|}}
                    <span class="px-3 py-1 rounded-full bg-indigo-100 dark:bg-indigo-900/30 text-indigo-700 dark:text-indigo-300 text-xs font-bold ring-1 ring-indigo-200 dark:ring-indigo-700">{{sport}}</span>
                  {{/each}}
                </div>
              </section>
            </div>

            <div class="lg:col-span-2 space-y-8">
              {{#if (or @profile.user_life_history.school_name @profile.user_life_history.college_name @profile.user_life_history.university_name)}}
              <section>
                <h3 class="text-sm font-bold text-gray-900 dark:text-white border-l-4 border-indigo-500 pl-3 mb-4">Education</h3>
                <div class="space-y-3">
                  {{#if @profile.user_life_history.school_name}}
                    <div class="rounded-2xl bg-gray-50 dark:bg-gray-800/50 p-5 border border-gray-100 dark:border-gray-700 flex items-start justify-between gap-4">
                      <div>
                        <p class="font-bold text-gray-900 dark:text-white">{{@profile.user_life_history.school_name}}</p>
                        <p class="text-xs text-gray-400 mt-0.5">School</p>
                      </div>
                      {{#if @profile.user_life_history.school_start_date}}
                        <span class="text-[11px] font-bold text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/30 px-2.5 py-0.5 rounded-full shrink-0">{{@profile.user_life_history.school_start_date}}</span>
                      {{/if}}
                    </div>
                  {{/if}}
                  {{#if @profile.user_life_history.college_name}}
                    <div class="rounded-2xl bg-gray-50 dark:bg-gray-800/50 p-5 border border-gray-100 dark:border-gray-700 flex items-start justify-between gap-4">
                      <div>
                        <p class="font-bold text-gray-900 dark:text-white">{{@profile.user_life_history.college_name}}</p>
                        <p class="text-xs text-gray-400 mt-0.5">College</p>
                      </div>
                      <div class="text-right shrink-0 space-y-1">
                        {{#if (or @profile.user_life_history.college_start_date @profile.user_life_history.college-start-at)}}
                          <span class="block text-[11px] font-bold text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/30 px-2.5 py-0.5 rounded-full">{{or @profile.user_life_history.college_start_date @profile.user_life_history.college-start-at}}</span>
                        {{/if}}
                        {{#if @profile.user_life_history.college_end_date}}
                          <span class="block text-[11px] font-bold text-gray-500 bg-gray-200 dark:bg-gray-700 px-2.5 py-0.5 rounded-full">{{@profile.user_life_history.college_end_date}}</span>
                        {{/if}}
                      </div>
                    </div>
                  {{/if}}
                  {{#if @profile.user_life_history.university_name}}
                    <div class="rounded-2xl bg-gray-50 dark:bg-gray-800/50 p-5 border border-gray-100 dark:border-gray-700 flex items-start justify-between gap-4">
                      <div>
                        <p class="font-bold text-gray-900 dark:text-white">{{@profile.user_life_history.university_name}}</p>
                        <p class="text-xs text-gray-400 mt-0.5">University</p>
                      </div>
                      <div class="text-right shrink-0 space-y-1">
                        {{#if @profile.user_life_history.university_start_date}}
                          <span class="block text-[11px] font-bold text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/30 px-2.5 py-0.5 rounded-full">{{@profile.user_life_history.university_start_date}}</span>
                        {{/if}}
                        {{#if @profile.user_life_history.university_end_date}}
                          <span class="block text-[11px] font-bold text-gray-500 bg-gray-200 dark:bg-gray-700 px-2.5 py-0.5 rounded-full">{{@profile.user_life_history.university_end_date}}</span>
                        {{/if}}
                      </div>
                    </div>
                  {{/if}}
                </div>
              </section>
              {{/if}}

              {{#if @profile.user_life_history.job}}
                <section>
                  <h3 class="text-sm font-bold text-gray-900 dark:text-white border-l-4 border-indigo-500 pl-3 mb-4">Work Experience</h3>
                  <div class="space-y-3">
                    {{#each @profile.user_life_history.job as |job|}}
                      <div class="rounded-2xl bg-gray-50 dark:bg-gray-800/50 p-5 border border-gray-100 dark:border-gray-700 flex items-start justify-between gap-4">
                        <div>
                          <p class="font-bold text-gray-900 dark:text-white">{{job.job_name}}</p>
                          <p class="text-xs text-gray-400 mt-0.5">Job</p>
                        </div>
                        <div class="text-right shrink-0 space-y-1">
                          {{#if job.job-start-at}}
                            <span class="block text-[11px] font-bold text-blue-600 dark:text-blue-400 bg-blue-100 dark:bg-blue-900/30 px-2.5 py-0.5 rounded-full">{{job.job-start-at}}</span>
                          {{/if}}
                          {{#if job.job-end-at}}
                            <span class="block text-[11px] font-bold text-gray-500 bg-gray-200 dark:bg-gray-700 px-2.5 py-0.5 rounded-full">{{job.job-end-at}}</span>
                          {{/if}}
                        </div>
                      </div>
                    {{/each}}
                  </div>
                </section>
              {{/if}}
            </div>
          </div>
        </div>

      {{else}}
        {{! Sport tabs — cricket/football render their own full content including header+body }}
        {{#if this.loadingSport}}
          {{! Loading state shown in header above; content area empty }}
        {{else if this.sportError}}
          <div class="px-4 sm:px-6 md:px-10 py-6">
            <div class="flex flex-col items-center justify-center py-20 gap-3">
              <span class="text-4xl">⚠️</span>
              <p class="text-red-500 dark:text-red-400 text-sm font-medium">{{this.sportError}}</p>
            </div>
          </div>
        {{else if this.sportLoaded}}
          {{#if (eq this.activeTab "cricket")}}
            <CricketProfile
              @profile={{@profile}}
              @sportData={{this.currentSportData}}
              @host={{this.host}}
              @isCurrentUser={{@isCurrentUser}}
              @onOpenPhotoUploader={{this.openSportPhotoUploader}}
            />
          {{else if (eq this.activeTab "football")}}
            <FootballProfile
              @profile={{@profile}}
              @sportData={{this.currentSportData}}
              @host={{this.host}}
              @isCurrentUser={{@isCurrentUser}}
              @onOpenPhotoUploader={{this.openSportPhotoUploader}}
            />
          {{else}}
            <div class="px-4 sm:px-6 md:px-10 py-6 sm:py-8">
              <div class="flex flex-col items-center justify-center py-20 gap-4 text-center">
                <span class="text-6xl">🏅</span>
                <p class="text-lg font-bold text-gray-700 dark:text-gray-200 capitalize">{{this.activeTab}} Profile</p>
                <p class="text-sm text-gray-400 dark:text-gray-500 max-w-xs">Detailed stats for this sport are coming soon.</p>
              </div>
            </div>
          {{/if}}
          {{! ── Gallery — common for every sport tab ── }}
          <SportGallery
            @sport={{this.activeTab}}
            @userId={{@profile.userid}}
            @host={{this.host}}
          />
        {{else}}
          <div class="px-4 sm:px-6 md:px-10 py-6">
            <div class="text-center py-20">
              <span class="text-5xl block mb-4">🏅</span>
              <p class="text-gray-400 dark:text-gray-500 text-sm capitalize">Click the {{this.activeTab}} tab to load stats.</p>
            </div>
          </div>
        {{/if}}
      {{/if}}

      {{! ── Modals ── }}

      {{! Sport Picker }}
      {{#if this.showSportPicker}}
        <div class="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true" aria-label="Select a sport">
          <div class="absolute inset-0 bg-black/70 backdrop-blur-sm" {{on "click" this.closeSportPicker}}></div>
          <div class="relative z-10 w-full max-w-md bg-gray-900 rounded-2xl shadow-2xl ring-1 ring-white/10 overflow-hidden">
            <div class="flex items-center justify-between px-6 py-5 border-b border-white/10">
              <div>
                <h2 class="text-lg font-extrabold text-white tracking-tight">Add Sports Profile</h2>
                <p class="text-xs text-gray-400 mt-0.5">Choose a sport to build your profile</p>
              </div>
              <button type="button" aria-label="Close sport picker" {{on "click" this.closeSportPicker}}
                class="flex items-center justify-center w-8 h-8 rounded-full bg-white/5 hover:bg-white/10 text-gray-400 hover:text-white transition-colors">
                {{lucideIcon "x" size=16}}
              </button>
            </div>
            <div class="overflow-y-auto max-h-[60vh] divide-y divide-white/5">
              {{#if this.availableSports.length}}
                {{#each this.availableSports as |sport|}}
                  <button type="button" {{on "click" (fn this.selectSport sport)}}
                    class="w-full flex items-center gap-4 px-6 py-4 text-left hover:bg-indigo-500/10 focus:bg-indigo-500/10 group transition-all duration-150 outline-none">
                    <span class="flex items-center justify-center w-11 h-11 rounded-full bg-gradient-to-br from-indigo-600/30 to-violet-600/30 border border-indigo-500/30 group-hover:border-indigo-400/60 group-hover:from-indigo-600/50 group-hover:to-violet-600/50 text-2xl shrink-0 transition-all duration-150 shadow-md group-hover:shadow-indigo-500/20">
                      {{sport.emoji}}
                    </span>
                    <span class="flex-1 font-bold text-gray-200 group-hover:text-white text-sm tracking-wide transition-colors">{{sport.label}}</span>
                    <span class="text-gray-600 group-hover:text-indigo-400 group-hover:translate-x-0.5 transition-all duration-150">
                      {{lucideIcon "chevron-right" size=18}}
                    </span>
                  </button>
                {{/each}}
              {{else}}
                <div class="flex flex-col items-center justify-center py-16 px-6 text-center">
                  <span class="text-4xl mb-3">🏅</span>
                  <p class="text-sm font-semibold text-gray-300">More Sports Coming Soon</p>
                  <p class="text-xs text-gray-500 mt-1">Cricket is the only available sport right now.</p>
                </div>
              {{/if}}
            </div>
          </div>
        </div>
      {{/if}}

      {{! Sports Profile Form }}
      {{#if this.showProfileForm}}
        <SportProfileForm
          @selectedSport={{this.selectedSport}}
          @isEditMode={{this.isEditMode}}
          @isSaving={{this.isSaving}}
          @saveError={{this.saveError}}
          @saveDisabled={{this.saveDisabled}}
          @nickName={{this.nickName}}
          @jerseyNumber={{this.jerseyNumber}}
          @matchFee={{this.matchFee}}
          @tournamentFee={{this.tournamentFee}}
          @selectedSkills={{this.selectedSkills}}
          @selectedPositions={{this.selectedPositions}}
          @skillSearch={{this.skillSearch}}
          @positionSearch={{this.positionSearch}}
          @showSkillDropdown={{this.showSkillDropdown}}
          @showPositionDropdown={{this.showPositionDropdown}}
          @filteredSkillOptions={{this.filteredSkillOptions}}
          @filteredPositionOptions={{this.filteredPositionOptions}}
          @sportMeta={{this.sportMeta}}
          @roleRows={{this.roleRows}}
          @careerHighlights={{this.careerHighlights}}
          @onClose={{this.closeProfileForm}}
          @onSubmit={{this.saveSportsProfile}}
          @onUpdateField={{this.updateField}}
          @onUpdateSkillSearch={{this.updateSkillSearch}}
          @onOpenSkillDropdown={{this.openSkillDropdown}}
          @onCloseSkillDropdown={{this.closeSkillDropdown}}
          @onToggleSkillDropdown={{this.toggleSkillDropdown}}
          @onSelectSkill={{this.selectSkill}}
          @onRemoveSkillTag={{this.removeSkillTag}}
          @onUpdatePositionSearch={{this.updatePositionSearch}}
          @onOpenPositionDropdown={{this.openPositionDropdown}}
          @onClosePositionDropdown={{this.closePositionDropdown}}
          @onTogglePositionDropdown={{this.togglePositionDropdown}}
          @onSelectPosition={{this.selectPosition}}
          @onRemovePositionTag={{this.removePositionTag}}
          @onAddHighlight={{this.addHighlight}}
          @onRemoveHighlight={{this.removeHighlight}}
          @onUpdateHighlight={{this.updateHighlight}}
          @onUpdateRoleField={{this.updateRoleField}}
          @onAddRoleRow={{this.addRoleRow}}
          @onRemoveRoleRow={{this.removeRoleRow}}
        />
      {{/if}}

    </div>

    {{! Photo Upload Modal }}
    {{#if this.showPhotoUploader}}
      <div class="fixed inset-0 z-50 flex items-center justify-center p-4" role="dialog" aria-modal="true" aria-label="Upload profile photo">
        <div class="absolute inset-0 bg-black/60 backdrop-blur-sm" {{on "click" this.closePhotoUploader}}></div>
        <div class="relative z-10 w-full max-w-sm bg-white dark:bg-gray-900 rounded-2xl shadow-2xl p-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-base font-bold text-gray-900 dark:text-white">Upload Profile Photo</h3>
            <button type="button" {{on "click" this.closePhotoUploader}}
              class="w-8 h-8 flex items-center justify-center rounded-full hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-500 transition-colors"
              aria-label="Close">
              {{lucideIcon "x" size=16}}
            </button>
          </div>
          <ImageUploader @type="general" @aspectRatio="1/1" @multiple={{false}} @onChange={{this.handlePhotoChange}} />
        </div>
      </div>
    {{/if}}

  </template>
}
