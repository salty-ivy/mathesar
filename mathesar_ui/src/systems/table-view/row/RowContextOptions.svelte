<script lang="ts">
  import { _ } from 'svelte-i18n';

  import { iconDeleteMajor } from '@mathesar/icons';
  import { confirmDelete } from '@mathesar/stores/confirmation';
  import { storeToGetRecordPageUrl } from '@mathesar/stores/storeBasedUrls';
  import {
    type RecordRow,
    RecordsData,
    rowHasRecord,
  } from '@mathesar/stores/table-data';
  import { getRowSelectionId } from '@mathesar/stores/table-data/records';
  import { toast } from '@mathesar/stores/toast';
  import {
    ButtonMenuItem,
    LinkMenuItem,
    iconExternalLink,
  } from '@mathesar-component-library';

  export let row: RecordRow;
  export let recordPk: string;
  export let recordsData: RecordsData;

  const canViewLinkedEntities = true;

  async function handleDeleteRecords() {
    if (rowHasRecord(row)) {
      void confirmDelete({
        identifierType: $_('record'),
        body: [
          $_('deleted_records_cannot_be_recovered', { values: { count: 1 } }),
          $_('are_you_sure_to_proceed'),
        ],
        onProceed: () => recordsData.deleteSelected(getRowSelectionId(row)),
        onError: (e) => toast.fromError(e),
        onSuccess: () =>
          toast.success({
            title: $_('record_deleted_successfully'),
          }),
      });
    }
  }
</script>

{#if canViewLinkedEntities}
  <LinkMenuItem
    href={$storeToGetRecordPageUrl({ recordId: recordPk }) || ''}
    icon={iconExternalLink}
  >
    {$_('go_to_record_page')}
  </LinkMenuItem>
{/if}
<ButtonMenuItem on:click={handleDeleteRecords} icon={iconDeleteMajor}>
  {$_('delete_records', { values: { count: 1 } })}
</ButtonMenuItem>
