<script lang="ts">
  import { _ } from 'svelte-i18n';

  import type { Role } from '@mathesar/models/Role';
  import type { ImmutableMap } from '@mathesar-component-library';

  import OverviewSection from './OverviewSection.svelte';
  import RoleWithChildren from './RoleWithChildren.svelte';
  import type { PermissionsMetaData } from './utils';

  type Privilege = $$Generic;

  export let roles: ImmutableMap<Role['oid'], Role>;
  export let permissionsMetaData: PermissionsMetaData<Privilege>;
</script>

<OverviewSection title={$_('owner')}>
  <RoleWithChildren rolesMap={roles} roleOid={permissionsMetaData.owner_oid} />
</OverviewSection>
