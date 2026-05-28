import TeamList from './teams/team-list';

<template>
  <TeamList @items={{@teams}} @onEdit={{@onEdit}} @onDelete={{@onDelete}} />
</template>
