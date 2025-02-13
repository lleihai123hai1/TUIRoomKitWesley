<template>
  <div>
    <div class="end-button" tabindex="1" @click="stopMeeting">{{ t('End') }}</div>
    <Dialog
      :model-value="visible"
      class="custom-element-class"
      :title="title"
      :modal="true"
      :append-to-body="false"
      width="420px"
      :before-close="cancel"
      :close-on-click-modal="true"
    >
      <div v-if="currentDialogType === DialogType.BasicDialog">
        <span v-if="roomStore.isMaster">
          <!-- eslint-disable-next-line max-len -->
          {{ t('You are currently the room host, please select the appropriate action.If you select "Leave Room", the room will not be dissolved and you will need to appoint a new host.') }}
        </span>
        <span v-else>{{ t('Are you sure you want to leave this room?') }}</span>
      </div>
      <div v-if="currentDialogType === DialogType.TransferDialog">
        <div>{{ t('New host') }}</div>
        <div>
          <el-select
            v-model="selectedUser"
            :teleported="false"
            :popper-append-to-body="false"
          >
            <el-option
              v-for="user in remoteAnchorList"
              :key="user.userId"
              :value="user.userId"
              :label="user.userName"
            />
          </el-select>
        </div>
      </div>
      <template #footer>
        <div v-if="currentDialogType === DialogType.BasicDialog">
          <el-button v-if="roomStore.isMaster" type="primary" @click.stop="dismissRoom">
            {{ t('Dismiss') }}
          </el-button>
          <el-button v-if="showLeaveRoom" type="primary" @click="leaveRoom">{{ t('Leave') }}</el-button>
          <el-button @click.stop="cancel">{{ t('Cancel') }}</el-button>
        </div>
        <div v-if="currentDialogType === DialogType.TransferDialog">
          <el-button type="primary" @click="transferAndLeave">{{ t('Transfer and leave') }}</el-button>
          <el-button @click.stop="cancel">{{ t('Cancel') }}</el-button>
        </div>
      </template>
    </Dialog>
  </div>
</template>

<script setup lang="ts">
import { onUnmounted, ref, Ref, computed, watch } from 'vue';
import { ElMessageBox, ElMessage } from '../../elementComp';
import TUIRoomEngine, { TUIRole, TUIRoomEvents } from '@tencentcloud/tuiroom-engine-electron';
import { useBasicStore } from '../../stores/basic';
import { useRoomStore } from '../../stores/room';
import { storeToRefs } from 'pinia';
import { useI18n } from '../../locales';
import useGetRoomEngine from '../../hooks/useRoomEngine';
import Dialog from '../../elementComp/Dialog.vue';

const roomEngine = useGetRoomEngine();

const { t } = useI18n();

const logPrefix = '[EndControl]';

enum DialogType {
  BasicDialog,
  TransferDialog
}
const currentDialogType = ref(DialogType.BasicDialog);

const emit = defineEmits(['on-exit-room', 'on-destroy-room']);

const visible: Ref<boolean> = ref(false);
const basicStore = useBasicStore();
console.log(`${logPrefix} basicStore:`, basicStore);

const roomStore = useRoomStore();
const { localUser, remoteAnchorList } = storeToRefs(roomStore);

const title = computed(() => (currentDialogType.value === DialogType.BasicDialog ? t('Leave room?') : t('Select a new host')));
const showLeaveRoom = computed(() => (
  roomStore.isMaster && remoteAnchorList.value.length > 0)
  || !roomStore.isMaster);

const selectedUser: Ref<string> = ref('');

function resetState() {
  visible.value = false;
  currentDialogType.value = DialogType.BasicDialog;
}

function stopMeeting() {
  if (!visible.value) {
    visible.value = true;
  }
}

function cancel() {
  resetState();
}

async function closeMediaBeforeLeave() {
  if (localUser.value.hasAudioStream) {
    await roomEngine.instance?.closeLocalMicrophone();
  }
  if (localUser.value.hasVideoStream) {
    await roomEngine.instance?.closeLocalCamera();
  }
}

/**
 * Active room dismissal
 *
 * 主动解散房间
**/
async function dismissRoom() {
  try {
    console.log(`${logPrefix}dismissRoom: enter`);
    await closeMediaBeforeLeave();
    await roomEngine.instance?.destroyRoom();
    resetState();
    emit('on-destroy-room', { code: 0, message: '' });
  } catch (error) {
    console.error(`${logPrefix}dismissRoom error:`, error);
  }
}

/**
 * Leave the room voluntarily
 *
 * 主动离开房间
**/
async function leaveRoom() { // eslint-disable-line
  try {
    if (roomStore.isMaster) {
      currentDialogType.value = DialogType.TransferDialog;
      return;
    }
    await closeMediaBeforeLeave();
    const response = await roomEngine.instance?.exitRoom();
    console.log(`${logPrefix}leaveRoom:`, response);
    resetState();
    emit('on-exit-room', { code: 0, message: '' });
  } catch (error) {
    console.error(`${logPrefix}leaveRoom error:`, error);
  }
}

async function transferAndLeave() {
  if (!selectedUser.value) {
    return;
  }
  try {
    const userId = selectedUser.value;
    const changeUserRoleResponse = await roomEngine.instance?.changeUserRole({ userId, userRole: TUIRole.kRoomOwner });
    console.log(`${logPrefix}transferAndLeave:`, changeUserRoleResponse);
    await closeMediaBeforeLeave();
    const exitRoomResponse = await roomEngine.instance?.exitRoom();
    console.log(`${logPrefix}exitRoom:`, exitRoomResponse);
    resetState();
    emit('on-exit-room', { code: 0, message: '' });
  } catch (error) {
    console.error(`${logPrefix}transferAndLeave error:`, error);
  }
}

/**
 * notification of room dismissal from the host
 *
 * 收到主持人解散房间通知
**/
const onRoomDismissed = async (eventInfo: { roomId: string}) => {
  try {
    const { roomId } = eventInfo;
    console.log(`${logPrefix}onRoomDismissed:`, roomId);
    ElMessageBox.alert(t('The host closed the room.'), t('Note'), {
      customClass: 'custom-element-class',
      confirmButtonText: t('Confirm'),
      appendTo: '#roomContainer',
      callback: async () => {
        resetState();
        emit('on-destroy-room', { code: 0, message: '' });
      },
    });
  } catch (error) {
    console.error(`${logPrefix}onRoomDestroyed error:`, error);
  }
};

/**
 * By listening for a change in ownerId,
 * the audience receives a notification that the host has handed over the privileges
 *
**/

const onUserRoleChanged = async (eventInfo: {userId: string, userRole: TUIRole }) => {
  if (eventInfo.userRole === TUIRole.kRoomOwner) {
    const { userId } = eventInfo;
    let newName = roomStore.getUserName(userId) || userId;
    if (userId === localUser.value.userId) {
      newName = t('me');
    }
    const tipMessage = `${t('Moderator changed to ')}${newName}`;
    ElMessage({
      type: 'success',
      message: tipMessage,
    });
    if (roomStore.localUser.userId === userId) {
      roomStore.setLocalUser({ userRole: TUIRole.kRoomOwner });
    } else {
      roomStore.setRemoteUserRole(userId, TUIRole.kRoomOwner);
    }
    roomStore.setMasterUserId(userId);
    resetState();
  }
};

TUIRoomEngine.once('ready', () => {
  roomEngine.instance?.on(TUIRoomEvents.onRoomDismissed, onRoomDismissed);
  roomEngine.instance?.on(TUIRoomEvents.onUserRoleChanged, onUserRoleChanged);
});

onUnmounted(() => {
  roomEngine.instance?.off(TUIRoomEvents.onRoomDismissed, onRoomDismissed);
  roomEngine.instance?.off(TUIRoomEvents.onUserRoleChanged, onUserRoleChanged);
});

</script>
<style lang="scss" scoped>
@import '../../assets/style/var.scss';
  .end-button {
    width: 90px;
    height: 40px;
    border: 2px solid #FF2E2E;
    border-radius: 4px;
    font-weight: 400;
    font-size: 14px;
    color: #FF2E2E;
    letter-spacing: 0;
    cursor: pointer;
    text-align: center;
    line-height: 36px;
    &:hover {
      background-color: #FF2E2E;
      color: $whiteColor;
    }
  }
</style>
